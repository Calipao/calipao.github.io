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

## 3D desk (home page, Godot build)

The home page embeds an interactive desk made in **Godot 4.7** (`godot/`): a CRT monitor running a terminal (`help`, `projects`, `show 1`, `open 1`, `about`, `experience`, `contact`), project cartridges that load their details in the terminal, an About notebook and a contact card.

- The Godot project builds the whole scene from code (`godot/scripts/main.gd`); the terminal is `godot/scripts/terminal.gd`.
- The night city outside the window, including the flickering windows, is `godot/scripts/city.gd`.
- Content comes from the page itself: `_layouts/desk.html` embeds the same data as `/assets/data/portfolio.json` (`window.DESK_DATA`), which Godot reads through `JavaScriptBridge`. Editing `_data/` and `_projects/` updates the desk.
- It uses the single-threaded web export, which GitHub Pages can serve without special headers.
- Visitors without WebGL 2, or who prefer reduced motion, get the plain text home page; anyone can switch views.

### Building and publishing

GitHub Pages can't run Godot, so `.github/workflows/pages.yml` downloads Godot, exports the desk to `assets/godot/`, builds the Jekyll site and deploys it.

1. In the repository, go to **Settings → Pages → Build and deployment** and set **Source** to **GitHub Actions**.
2. Push to the default branch. Runs on other branches attach the built site as a `site-preview` artifact instead of deploying.

To work on the desk locally, open `godot/project.godot` in Godot 4.7. When run in the editor it uses `godot/sample_data.json`. Without an export in `assets/godot/`, the local Jekyll preview falls back to the text home page.

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000>.

See `OUTLINE.md` for the full site plan.
