# calipao.github.io

Lin Xin's portfolio, built with Jekyll and the `jekyll-theme-hacker` theme and hosted on GitHub Pages at <https://calipao.github.io>.

## Editing content

| What | Where |
|------|-------|
| Name, title, tagline, links, skills | `_data/profile.yml` |
| Home page | `index.md` |
| About page (bio, experience, education) | `about.md` |
| Projects | one Markdown file per project in `_projects/` |
| Styles | `assets/css/style.scss` |
| Images, résumé PDF | `assets/images/`, `assets/` |

### Adding a project

Copy `_projects/project-1.md` to `_projects/<slug>.md` and fill in the front matter:

- `featured: true` shows it on the home page (first 3 by `order`).
- `order` sets the sort order (lower comes first).
- `repo`, `demo`, `writeup` add links; leave them out to hide them.
- `image` is an optional 16:9 screenshot in `assets/images/`.

### Adding the résumé

Put the PDF at `assets/resume.pdf` and set `resume: /assets/resume.pdf` in `_data/profile.yml`. A résumé link then appears in the navigation and contact links.

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000>.

See `OUTLINE.md` for the full site plan.
