"""公開用スクリプトの検査。sync-to-qiita.sh の画像置換と set-publish-date.sh の予約設定。"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = 'https://raw.githubusercontent.com/iineineno03k/articles/main/images'

ARTICLE = '''---
title: "t"
emoji: "x"
type: "tech"
topics: ["A"]
published: false
---

本文
![a](/images/s1/a.png)
![b](/images/s1/b.png)
`$HOME` はそのまま
'''


class Repo(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        (self.root / 'articles').mkdir()
        (self.root / 'articles/s1.md').write_text(ARTICLE)
        (self.root / 'images/s1').mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.root)

    def run_script(self, name, *args):
        return subprocess.run(['bash', str(self.root / 'scripts' / name), *args],
                              capture_output=True, text=True, timeout=20)


class SyncToQiitaTest(Repo):
    def put_images(self, *names):
        for n in names:
            (self.root / 'images/s1' / n).write_bytes(b'png')

    def test_images_in_repo_become_raw_urls(self):
        self.put_images('a.png', 'b.png')
        r = self.run_script('sync-to-qiita.sh', 's1')
        self.assertEqual(r.returncode, 0, r.stderr)
        out = (self.root / 'public/s1.md').read_text()
        self.assertIn(f'![a]({RAW}/s1/a.png)', out)
        self.assertIn(f'![b]({RAW}/s1/b.png)', out)
        self.assertNotIn('](/images/', out)
        self.assertIn('`$HOME` はそのまま', out)

    def test_map_overrides_raw_url(self):
        self.put_images('a.png', 'b.png')
        (self.root / 'images/s1/qiita-urls.tsv').write_text('a.png\thttps://x.example/a.png?x=1&y=2\n')
        r = self.run_script('sync-to-qiita.sh', 's1')
        self.assertEqual(r.returncode, 0, r.stderr)
        out = (self.root / 'public/s1.md').read_text()
        self.assertIn('![a](https://x.example/a.png?x=1&y=2)', out)
        self.assertIn(f'![b]({RAW}/s1/b.png)', out)

    def test_missing_image_file_stops_publish(self):
        self.put_images('a.png')
        r = self.run_script('sync-to-qiita.sh', 's1')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('/images/s1/b.png', r.stderr)
        self.assertFalse((self.root / 'public/s1.md').exists())

    def test_other_image_syntaxes_fail_safely(self):
        self.put_images('a.png', 'b.png', 'c.png')
        head = ARTICLE.split('本文')[0]
        for body in ('![c][r]\n\n[r]: /images/s1/c.png\n', '<img src="/images/s1/c.png">\n', '![c](</images/s1/c.png>)\n'):
            with self.subTest(body=body):
                (self.root / 'articles/s1.md').write_text(head + body)
                self.assertNotEqual(self.run_script('sync-to-qiita.sh', 's1').returncode, 0)

    def test_rejects_non_https_map_url(self):
        self.put_images('a.png', 'b.png')
        (self.root / 'images/s1/qiita-urls.tsv').write_text('a.png\t/images/s1/a.png\n')
        r = self.run_script('sync-to-qiita.sh', 's1')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('https://', r.stderr)


class SetPublishDateTest(Repo):
    def test_sets_published_and_date(self):
        r = self.run_script('set-publish-date.sh', 's1', '2030-01-07 08:00')
        self.assertEqual(r.returncode, 0, r.stderr)
        text = (self.root / 'articles/s1.md').read_text()
        self.assertIn('published: true\npublished_at: "2030-01-07 08:00"\n', text)
        self.assertNotIn('published: false', text)

    def test_reschedule_replaces_date(self):
        self.run_script('set-publish-date.sh', 's1', '2030-01-07 08:00')
        self.run_script('set-publish-date.sh', 's1', '2030-01-08 08:00')
        text = (self.root / 'articles/s1.md').read_text()
        self.assertEqual(text.count('published_at:'), 1)
        self.assertIn('2030-01-08 08:00', text)

    def test_default_is_a_weekday_8am(self):
        r = self.run_script('set-publish-date.sh', 's1')
        self.assertEqual(r.returncode, 0, r.stderr)
        line = [l for l in (self.root / 'articles/s1.md').read_text().splitlines() if l.startswith('published_at:')][0]
        self.assertTrue(line.endswith(' 08:00"'), line)


if __name__ == '__main__':
    unittest.main()
