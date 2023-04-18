import psycopg2
from psycopg2.extras import RealDictCursor
try:
    connection = psycopg2.connect(user="flow",
                                  password="flowed!tor",
                                  host="localhost",
                                  port="5432",
                                  database="flow")
    cursor = connection.cursor(cursor_factory=RealDictCursor)
    postgreSQL_select_Query = "SELECT t.index, nc.orthographe, nc.autorite, t.ref_taxon_parent, t.family FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index LEFT JOIN statuts AS s ON txn.ref_statut = s.index LEFT JOIN rangs AS r ON t.ref_rang = r.index WHERE r.en = 'species' AND s.en = 'valid' AND nc.orthographe ORDER BY nc.orthographe LIMIT 3"

    cursor.execute(postgreSQL_select_Query)
    print("Selecting rows from names table using cursor.fetchall")
    names_records = cursor.fetchall()

    print("Print each row and it's columns values")
    for i in range(len(names_records)):
        print("Index = ", names_records[i]['t.index'],  " Orthographe = ", names_records[i]['nc.orthographe'])

except (Exception, psycopg2.Error) as error:
    print("Error while fetching data from PostgreSQL", error)


finally:
    # closing database connection.
    if connection:
        cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")

