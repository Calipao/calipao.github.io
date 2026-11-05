---
layout: default
title: About
permalink: /about/
---
{%- assign p = site.data.profile -%}
# About me

<!-- Optional photo: add assets/images/avatar.jpg and uncomment
<img src="{{ '/assets/images/avatar.jpg' | relative_url }}" alt="Photo of {{ p.name }}" width="160">
-->

I'm a software engineer and game developer based in Singapore. I'm a Programmer at KOEI TECMO Singapore and Technical Director at Gearbyte Games.

I studied Real-Time Interactive Simulation at DigiPen Institute of Technology Singapore, after a Diploma in Game Design and Technology from Nanyang Polytechnic. Before games, I built business software and websites at Echol and Spot Works.

## Experience

### Programmer — KOEI TECMO Singapore
*April 2025 – Present · Singapore*

<!-- Add 2–3 bullets on what you work on, e.g. systems, tools or titles you can mention publicly. -->

### Intern Programmer — KOEI TECMO Singapore
*September 2024 – April 2025 · Singapore*

### Technical Director — Gearbyte Games
*May 2024 – Present · Singapore*

<!-- Add 2–3 bullets on your responsibilities and the games the studio has made. -->

### Teaching Assistant — DigiPen Institute of Technology Singapore
*September 2022 – April 2023 · Singapore*

- Provided guidance and support on a variety of programming concepts and assignments.
- Graded assignments and gave feedback to students.

### Software Developer — Echol
*March 2019 – July 2019 · Singapore*

- Contributed to the development of proprietary business support software.
- Deployed software for internal use.

### Web Developer — Spot Works
*September 2018 – November 2018 · Singapore*

- Developed and maintained the company's websites.
- Worked on a team to refurbish old webpages.

## Education

### BS, Real-Time Interactive Simulation — DigiPen Institute of Technology Singapore
*September 2021 – May 2025*

### Real-Time Interactive Simulation — DigiPen Institute of Technology
*April 2023 – August 2023*

### Diploma, Game Design and Technology — Nanyang Polytechnic
*2016 – 2019*

## Skills

<dl class="skills">
{% for group in p.skills %}
  <dt>{{ group.group }}</dt>
  <dd>{{ group.items | join: " · " }}</dd>
{% endfor %}
</dl>

## Contact

{% include contact-links.html %}
