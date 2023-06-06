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

### Local Installation with Container

To simplify the installation you can also use Docker containers.

Docker must be installed on you system.

To launch the database container:

```shell
docker-compose up -d
```

Create the databases:

```shell
docker exec -it flow_postgres_container psql -U postgres -c "CREATE DATABASE flow;"
docker exec -it flow_postgres_container psql -U postgres -c "CREATE DATABASE traduction_utf8;"
```

To import the dumps:

```shell
docker exec -i flow_postgres_container psql -U postgres -d flow < ./dumps/flow.sql
docker exec -i flow_postgres_container psql -U postgres -d traduction_utf8 < ./dumps/traduction_utf8.sql
```

Build server image:

```shell
docker build -t my-perl-app .
```

Run the image:

```shell
docker run -p 5000:5000 my-perl-app
```

Site can be found at

http://localhost:5000/flow