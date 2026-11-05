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

[Paragraph 1: who you are and your background.]

[Paragraph 2: what you're working on or studying now, and what you enjoy building.]

[Paragraph 3: what you're looking for next.]

## Experience

### [Role] — [Organization]
*[Month Year] – [Month Year / Present]*

- [What you did and the impact, with a number if possible.]
- [Another accomplishment.]

### [Role] — [Organization]
*[Month Year] – [Month Year]*

- [What you did and the impact.]

## Education

### [Degree, Major] — [School]
*[Year] – [Year]*

- [Relevant coursework, honors, or activities.]

## Skills

<dl class="skills">
{% for group in p.skills %}
  <dt>{{ group.group }}</dt>
  <dd>{{ group.items | join: " · " }}</dd>
{% endfor %}
</dl>

## Beyond work

[Optional: hobbies or interests.]

## Contact

{% include contact-links.html %}
