---
layout: default
title: Home
---
{%- assign p = site.data.profile -%}
<section class="hero">
  <p class="lead">{{ p.tagline }}</p>
  {%- if p.availability and p.availability != "" %}
  <p class="availability">{{ p.availability }}</p>
  {%- endif %}
  {% include contact-links.html %}
</section>

## Featured projects

{% assign featured = site.projects | where: "featured", true | sort: "order" %}
<div class="project-grid">
{% for project in featured limit: 3 %}
  {% include project-card.html project=project %}
{% endfor %}
</div>

[See all projects &rarr;]({{ '/projects/' | relative_url }})

## Skills

<dl class="skills">
{% for group in p.skills %}
  <dt>{{ group.group }}</dt>
  <dd>{{ group.items | join: " · " }}</dd>
{% endfor %}
</dl>

## Get in touch

{% if p.availability != "" %}{{ p.availability }} {% endif %}The quickest way to reach me is through the links below.

{% include contact-links.html %}
