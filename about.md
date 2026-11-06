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

{% for job in site.data.experience %}
### {{ job.role }} — {{ job.org }}
*{{ job.start }} – {{ job.end }}{% if job.location %} · {{ job.location }}{% endif %}*
{% if job.points.size > 0 %}
{% for point in job.points %}- {{ point }}
{% endfor %}{% endif %}
{% endfor %}

## Education

{% for edu in site.data.education %}
### {{ edu.qualification }} — {{ edu.school }}
*{{ edu.start }} – {{ edu.end }}*
{% endfor %}

## Skills

<dl class="skills">
{% for group in p.skills %}
  <dt>{{ group.group }}</dt>
  <dd>{{ group.items | join: " · " }}</dd>
{% endfor %}
</dl>

## Contact

{% include contact-links.html %}
