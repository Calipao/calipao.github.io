# calipao.github.io

Lin Xin's portfolio, built with Jekyll and the `jekyll-theme-hacker` theme and hosted on GitHub Pages at <https://calipao.github.io>.

## Editing content

| What | Where |
|------|-------|
| Name, title, tagline, links, skills | `_data/profile.yml` |
| Experience, education | `_data/experience.yml`, `_data/education.yml` |
| Home page | `index.md` |
| About page bio | `about.md` |
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

## 3D desk (home page)

The home page is an interactive 3D desk built with [three.js](https://threejs.org) (r187, vendored in `assets/vendor/three/`, no build step).

- Click the monitor, or just start typing, to use the terminal. Try `help`, `projects`, `open 1`, `about`, `experience`, `contact`.
- Each project in `_projects/` becomes a game cartridge on the desk; the notebook opens the About page; the business card runs `contact`.
- Everything the desk shows comes from `/assets/data/portfolio.json`, which Jekyll builds from `_data/` and `_projects/`, so editing those files updates the desk too.
- Visitors without WebGL, or who prefer reduced motion, get the plain text home page. Anyone can switch with the "text view" / "enter the 3D desk" links.

| What | Where |
|------|-------|
| Page layout and overlay | `_layouts/desk.html` |
| Scene objects | `assets/js/desk/props.js` |
| Camera, picking, view switching | `assets/js/desk/main.js` |
| Terminal commands | `assets/js/desk/terminal.js` |
| Experience and education | `_data/experience.yml`, `_data/education.yml` |

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000>.

See `OUTLINE.md` for the full site plan.
