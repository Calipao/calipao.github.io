---
layout: default
title: Projects
permalink: /projects/
---
# Projects

A selection of things I've built. Each one links to a short write-up with the code and a demo where available.

{% assign projects = site.projects | sort: "order" %}
<div class="project-grid">
{% for project in projects %}
  {% include project-card.html project=project %}
{% endfor %}
</div>
