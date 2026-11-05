# Portfolio Website Outline

Draft plan for **calipao.github.io**, Lin Xin's portfolio, hosted on GitHub Pages
with Jekyll and the `jekyll-theme-hacker` theme (set in `_config.yml`).

> Items in `[brackets]` are placeholders to fill in with real content.

---

## 1. Goals

- Introduce Lin Xin quickly: who they are, what they do, and what they want to do next.
- Show 3–6 strong projects with enough detail to show skill and impact.
- Make it easy to reach out: email, GitHub, LinkedIn, and a résumé download.
- Keep it fast, readable on phones, and easy to update by editing Markdown.

## 2. Site map

| Page | URL | Purpose |
|------|-----|---------|
| Home | `/` | Intro, highlights, links to everything else |
| Projects | `/projects/` | Full project list (cards) |
| Project detail | `/projects/<slug>/` | One page per featured project |
| About | `/about/` | Longer bio, skills, experience, education |
| Résumé | `/resume.pdf` | Downloadable PDF |
| Blog / Notes *(optional)* | `/blog/` | Write-ups, tutorials, learning notes |
| Contact | section on Home + About | Email and social links |
| 404 | `/404.html` | Friendly "not found" page with a link home |

## 3. Page-by-page content

### 3.1 Home (`index.md`)
1. **Hero**: name, one-line title (e.g. `[Software Engineer / Student / Designer]`), one-sentence pitch.
2. **Quick links**: GitHub · LinkedIn · Email · Résumé.
3. **Featured projects**: 3 cards (title, one-line summary, tech tags, links to the detail page, repo, and live demo).
4. **Skills snapshot**: grouped short lists (Languages · Frameworks · Tools).
5. **Recent activity** *(optional)*: latest 3 blog posts or updates.
6. **Contact call-to-action**: "Open to `[internships / full-time / freelance]` — get in touch."

### 3.2 Projects (`projects.md`)
- Grid or list of every project, newest or most impressive first.
- Each card: title, thumbnail/screenshot, 1–2 line summary, tech tags, links.
- Optional filter by tag (e.g. Web, Data, ML, Design).

### 3.3 Project detail (`_projects/<slug>.md`)
Use the same template for every project:
1. **Overview**: what it is and the problem it solves.
2. **My role**: solo or team; what Lin Xin built.
3. **Tech stack**.
4. **Key features**: 3–5 bullets, with screenshots or a GIF.
5. **Challenges and solutions**: the most interesting technical problem.
6. **Results**: metrics, users, awards, or what was learned.
7. **Links**: repository, live demo, write-up.

Starter project slots:
- `[Project 1]`: `[short description]`
- `[Project 2]`: `[short description]`
- `[Project 3]`: `[short description]`

### 3.4 About (`about.md`)
1. Photo or avatar *(optional)*.
2. Bio: 2–3 short paragraphs (background, interests, current focus).
3. **Experience**: role, organization, dates, 2–3 impact bullets each.
4. **Education**: school, degree, dates, notable coursework or honors.
5. **Skills**: detailed list, grouped.
6. **Beyond work** *(optional)*: hobbies or interests that add personality.

### 3.5 Blog / Notes (optional, `_posts/`)
- Jekyll posts named `YYYY-MM-DD-title.md`.
- Ideas: project post-mortems, "how I built X", things learned from courses.

### 3.6 Contact
- Email (consider an obfuscated `mailto:` link to reduce spam).
- GitHub: `https://github.com/calipao`.
- LinkedIn and other profiles: `[links]`.

## 4. Proposed repository structure

```
calipao.github.io/
├── _config.yml          # site title, description, theme, collections, plugins
├── index.md             # Home (replaces the current placeholder index.html)
├── about.md
├── projects.md
├── 404.md
├── resume.pdf
├── _projects/           # one Markdown file per project (Jekyll collection)
│   └── example-project.md
├── _posts/              # optional blog posts
├── _layouts/            # only if overriding the theme's default layout
│   └── project.html
├── _includes/           # reusable pieces: nav, project card, footer
│   ├── nav.html
│   └── project-card.html
└── assets/
    ├── images/          # screenshots, avatar, favicon
    └── css/style.scss   # small overrides on top of the hacker theme
```

## 5. Configuration changes (`_config.yml`)

```yaml
theme: jekyll-theme-hacker
title: Lin Xin's homepage
description: Portfolio website!   # replace with a real one-line pitch
url: "https://calipao.github.io"

collections:
  projects:
    output: true
    permalink: /projects/:name/

plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-feed        # only if the blog is used
```

## 6. Design notes

- The hacker theme is dark, monospace, and green-on-black. Keep it, or swap the
  theme later; content in Markdown stays the same either way.
- Add a simple top navigation (Home · Projects · About · Blog · Résumé), since the
  theme has none by default.
- Use consistent screenshot sizes (e.g. 16:9) for project cards.
- Check that it works on a phone and passes basic accessibility (alt text on images,
  readable contrast, descriptive link text).

## 7. Build plan / milestones

1. **Foundation**: replace `index.html` with `index.md`, update `_config.yml`,
   add navigation, write the README.
2. **Core content**: Home, About, and the résumé PDF.
3. **Projects**: set up the `projects` collection, the card include, and 3 project pages.
4. **Polish**: favicon, SEO tags, sitemap, 404 page, image optimization.
5. **Optional**: blog, tag filters, custom domain, analytics.

## 8. Content checklist (to gather)

- [ ] One-line title and short pitch
- [ ] Bio (2–3 paragraphs) and a photo/avatar
- [ ] Résumé PDF
- [ ] 3–6 projects: descriptions, screenshots, repo/demo links
- [ ] Experience and education details
- [ ] Contact email and social profile links
