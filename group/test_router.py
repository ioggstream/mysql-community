from mysql.connector import connect
import os
from contextlib import closing


def test_connect():
    c = connect(host='localhost',port='6446',user='root',password=os.environ['MYSQL_ROOT_PASSWORD'])
    with closing(c.cursor()) as cur:
        cur.execute('select @@report_host;')
        (host, ) = cur.fetchall()
        print("host: ", host)
        
        # Stop current master.
        cur.execute("SHUTDOWN")
        
        # This fails!
        try:
            cur.execute('select @@report_host;')
            (host, ) = cur.fetchall()
            print("host: ", host)
        except Exception as e:
            print("Cannot connect", e)
       
    

    # Reconnect to another host.
    c = connect(host='localhost',port='6446',user='root',password=os.environ['MYSQL_ROOT_PASSWORD'])
    
    with closing(c.cursor()) as cur:
        cur.execute('select @@report_host;')
        (host, ) = cur.fetchall()
        print("host: ", host)
    c.close()

    
