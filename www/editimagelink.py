import psycopg2
from psycopg2.extras import RealDictCursor
try:
    connection = psycopg2.connect(user="flow",
                                  password="flowed!tor",
                                  host="localhost",
                                  port="5432",
                                  database="flow")
    cursor = connection.cursor(cursor_factory=RealDictCursor)
    postgreSQL_select_Query = "SELECT * FROM public.images ORDER BY index ASC"

    cursor.execute(postgreSQL_select_Query)
    print("Selecting rows from images table")
    names_records = cursor.fetchall()

    print("Editing...in progress")
    for i in range(len(names_records)):
        print("Old link = Id: ", names_records[i]['index'],  " Url  = ", names_records[i]['url'])
        link = names_records[i]['url']
        link_icon = names_records[i]['icone_url']
        if link is not None:
            link = link.replace("http://hemiptera-databases.org","")
            link = link.replace("http://rameau.snv.jussieu.fr","")
        if link_icon is not None:
            link_icon = link_icon.replace("http://hemiptera-databases.org","")
            link_icon = link_icon.replace("http://rameau.snv.jussieu.fr","")

        print("New link = Id: ", names_records[i]['index'],  " Url  = ", link)
        querry = """ UPDATE public.images SET url = %s, icone_url = %s  WHERE index = %s """
        cursor.execute(querry,(link, link_icon, names_records[i]['index']))
        updated_rows = cursor.rowcount
        connection.commit()
        print("Updated , Url  = ", link)


except (Exception, psycopg2.Error) as error:
    print("Error while fetching data from PostgreSQL", error)


finally:
    # closing database connection.
    if connection:
        cursor.close()
        connection.close()
        print("PostgreSQL connection is closed")

