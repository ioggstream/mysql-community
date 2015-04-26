from __future__ import print_function
from os.path import isfile
import mysql.connector
from mysql.connector import fabric

fabric_user = dict(user="fabric", password="fabric")
admin_user= dict(user="admin", password="password")
root_user = dict(user='root', password='root')
hosts = "fabric.docker m.docker s-1.docker s-2.docker s-3.docker".split()

def f_create_fabric_user(hosts):
    """ Provision fabric user wit @@SESSION.SQL_LOG_BIN=0.
    """ 
    for h in hosts:
        try:
            c = mysql.connector.connect(host=h, **root_user)
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
    conn.set_property(mode=fabric.MODE_READWRITE, group="ha")
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
    

def test_fabric_cfg():
    assert isfile("/etc/mysql/fabric.cfg")

    assert 'Fabric Training File' in open("/etc/mysql/fabric.cfg").read()


def test_fabric_log():
    # This test will succeed after the 
    #  fabric startup with
    #  mysqlfabric manage start [--daemon]
    assert isfile("/var/log/fabric.log")


def test_fabric_user_and_database():
    # This test will succeed *after* the
    #  mysqlfabric manage setup, which will
    #  provision the database
    c = mysql.connector.connect(host='localhost', 
                                database='fabric',
                                **fabric_user)


def connect_node(h, myuser):
    c = mysql.connector.connect(host=h, **myuser)
    cur = c.cursor()
    cur.execute("select user,host from mysql.user;")
    for x in cur:
        pass
    cur.close()
    c.close()

def test_access_nodes_with_fabric_user():
    for h in hosts:
        yield connect_node, h, fabric_user
            
 
def test_access_nodes_with_root_user():
    for h in hosts:
        yield connect_node, h, root_user 
