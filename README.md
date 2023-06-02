# Projet DATAK

## Objectif

Le site [Planthoppers FLOW website](https://flow.hemiptera-databases.org/flow/?&lang=fr)
date d'une trentaine d'années; suite à des départs de personnes et un manque de documentation,
la maintenance n'est plus assurée.

Dans le cadre du projet DATAK, l'objectif est de parer au plus urgent en matière d'architecture
et de documentation afin que le site puisse être déployé facilement sur des plateformes
modernes.


Actuellement seule la page d'accueil est fonctionnelle. Reste à intégrer les multiples
scripts dans les sous-répertoires de cgi-bin, ajuster les chemins, essayer de séparer
les couches métier/javascript/database, etc.


TO BE CONTINUED -- WORK IN PROGRESS.


## Installation

```
cpanm --installdeps .  # va installer les modules "Plack" nécessaires au fonctionnement de l'appli
```

## Lancement en ligne de commande

```
plackup flow.psgi     # lance un serveur local, par défaut sur port 5000
```

Visiter la page http://localhost:5000/flow

