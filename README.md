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


## Prérequis

Un serveur Postgresql avec une database `flow` et une database `traduction_utf8`, chargées avec les
fichier SQL du répertoire `dumps`.
Les credentials de connexion (login, passwd) sont dans le fichier `flow_conf.yaml` à la racine du repository --
ajustez pour votre environnement.



## Installation

Le fichier `cpanfile` contient la liste des modules Perl nécessaires pour le fonctionnement de l'appli.
La commande ci-dessous installe toutes les dépendances.

```
cpanm --installdeps .
```

## Lancement de l'appli en ligne de commande

```
plackup flow.psgi     # lance un serveur local, par défaut sur port 5000
```

Visiter la page [http://localhost:5000/flow](http://localhost:5000/flow)

Un autre port peut être spécifié :

```
plackup -p 4999 flow.psgi
```

