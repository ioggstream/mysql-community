from __future__ import print_function
import mysql.connector
from mysql.connector import fabric

fabric_user = dict(user="fabric", password="fabric")
admin_user= dict(user="admin", password="password")
root = dict(user='root', password='root')


def f_create_fabric_user(hosts):
    for h in hosts:
        try:
            c = mysql.connector.connect(host=h, **root)
        except:
            print("cannot connect to ", h)
            continue
        cur = c.cursor()
        # If you specify only the user name part of the account name, a host name part of '%' is used.
        cur.execute("SET @@SESSION.SQL_LOG_BIN=0;")
        try:
            cur.execute("create user fabric identified by 'fabric';")
        except mysql.connector.errors.DatabaseError:
            pass
        cur.execute("grant all on *.* to {user}@'%' identified by '{password}';".format(**fabric_user))
        cur.close()
        c.close()
        print("User fabric created on ", h)


def f_configure_fabric():
    fabric_cfg = open('fabric.cfg.t').read()
    fabric_cfg = fabric_cfg.format(
                fabric_password=fabric_user['password'],
                admin_password=admin_user['password']
                )
    with open('/etc/mysql/fabric.cfg', 'wb') as fh:
        fh.write(fabric_cfg.encode('ascii'))


           
            
if __name__ == '__main__':
    dt = { k:v 
            for k,v in globals().items() 
            if (v.__class__.__name__ == 'function'
            and k.startswith('f_'))
            }
    from sys import argv
    action = argv[1]
    if action == 'setup':
        hosts = argv[2:]
        f_configure_fabric()
        f_create_fabric_user(hosts)
    elif action in dt:
        dt[action](argv[2:])
    elif action == 'list':
        print(dt.keys())
    else:
        raise ValueError("unsupported")

    exit(0)

from nose.tools import with_setup

def fabric_setup():    
    cred = {"host" : "localhost",
                "port" : 32274}
    cred.update(admin_user)
    conn = mysql.connector.connect(fabric=cred, autocommit=True, database='sample', **fabric_user
    )   
    conn.set_property(mode=fabric.MODE_READWRITE, group="group_id-1")
    cur = conn.cursor()
    cur.execute(
    "CREATE TABLE IF NOT EXISTS subscribers ("
    "   sub_no INT, "
    "   first_name CHAR(40), "
    "   last_name CHAR(40)"
    ")"
    ) 


@with_setup(fabric_setup)
def test_fabric():
    for h in 'm.docker s-1.docker'.split():
        try:
            print("host", h)
            c = mysql.connector.connect(host=h, database='sample', **fabric_user)
            cur = c.cursor()
            cur.execute("select * from subscribers;")
            for x in cur:
                pass
            cur.close()
            c.close()
        except Exception as e:
            print(e)
    

def test_fabric_node():
    c = mysql.connector.connect(host='localhost', 
                                database='fabric',
                                **fabric_user)


def test_access_nodes():
    def test_node(h):
        c = mysql.connector.connect(host=h, **fabric_user)
        cur = c.cursor()
        cur.execute("select user,host from mysql.user;")
        for x in cur:
            pass
        cur.close()
        c.close()

    for h in hosts:
        yield test_node, h
            
 
