"""
    Code for mysql-fabric:
        - configure
        - setup
        - test servers
        - test replication
        - test fabric access (rw split)
        - test shards (wip)

    Many functions are freely inspired by MySQL Fabric Tutorials
    http://dev.mysql.com/doc/mysql-utilities/1.5/en
"""
from __future__ import print_function
from os.path import isfile
import mysql.connector
from mysql.connector import fabric
from mysql.connector.errors import *
from time import sleep
import logging
log = logging.getLogger(__name__)
logging.basicConfig(level='DEBUG')

GROUP = "ha"

FABRIC_LOG = "/var/log/fabric.log"
FABRIC_CFG = '/etc/mysql/fabric.cfg'
hosts = "fabric.docker m.docker s-1.docker s-2.docker s-3.docker".split()

fabric_user = dict(user="fabric", password="fabric")
admin_user = dict(user="admin", password="password")
root_user = dict(user='root', password='root')
xmlrpc_endpoint = dict(host="localhost", port=32274)
xmlrpc_endpoint.update(admin_user)


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
            cur.execute("create user {user} identified by '{password}';".format(**fabric_user))
        except mysql.connector.errors.DatabaseError:
            pass
        cur.execute("grant all on *.* to {user}@'%' identified by '{password}';".format(**fabric_user))
        cur.close()
        c.close()
        print("User fabric created on ", h)


def f_configure_fabric():
    """
    Create /etc/mysql/fabric.cfg using the given template
    :return:
    """
    fabric_cfg = open('/code/fabric.cfg.t').read()
    fabric_cfg = fabric_cfg.format(
        xmlrpc_host=xmlrpc_endpoint['host'],
        xmlrpc_port=xmlrpc_endpoint['port'],
        fabric_password=fabric_user['password'],
        admin_password=admin_user['password']
    )
    with open(FABRIC_CFG, 'wb') as fh:
        fh.write(fabric_cfg.encode('ascii'))


if __name__ == '__main__':
    dt = {k: v
          for k, v in globals().items()
          if (v.__class__.__name__ == 'function') and k.startswith('f_')
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
from nose.tools import *
from nose import SkipTest

def get_fabric_cursor(mode):
    """
    Create a connection via Fabric
    :param mode:
    :return:
    """
    conn_rw = mysql.connector.connect(fabric=xmlrpc_endpoint, autocommit=True, database='sample', **fabric_user)
    conn_rw.set_property(mode=mode, group=GROUP)
    cur = conn_rw.cursor()
    return conn_rw, cur


def fabric_setup():
    conn, cur = get_fabric_cursor(fabric.MODE_READWRITE)
    cur.execute(
        "CREATE TABLE IF NOT EXISTS subscribers ("
        "   sub_no INT, "
        "   first_name CHAR(40), "
        "   last_name CHAR(40)"
        ")"
    )


def connect(mode):
    """
    Connect to a Group via Fabric.
    :param mode: fabric.MODE_READONLY or fabric.MODE_READWRITE
    :return:
    """
    conn_rw, cur = get_fabric_cursor(mode)
    cur.execute("SELECT @@hostname;")
    for x in cur:
        log.info("hostname connected in mode %s to %s", mode, x)
    cur.close()
    conn_rw.close()


def test_target_host():

    for m in (fabric.MODE_READWRITE, fabric.MODE_READONLY):
        for i in range(10):
            yield connect, m


def test_failover_host():
    for i in range(100):
        for m in (fabric.MODE_READWRITE, fabric.MODE_READONLY):
            yield connect, m
            sleep(1)




@with_setup(fabric_setup)
def test_fabric():
    for h in hosts:
        if h.startswith(('localhost', 'fabric')):
            continue
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
    assert isfile(FABRIC_CFG)

    assert 'Fabric Training File' in open(FABRIC_CFG).read()


def test_fabric_log():
    # This test will succeed after the 
    # fabric startup with
    #  mysqlfabric manage start [--daemon]
    assert isfile(FABRIC_LOG)


def test_fabric_user_and_database():
    # This test will succeed *after* the
    # mysqlfabric manage setup, which will
    #  provision the database
    try:
        c = mysql.connector.connect(
            host='localhost',
            database='fabric',
            **fabric_user)
    except InterfaceError:
        raise SkipTest()


def connect_node(h, myuser):
    try:
        c = mysql.connector.connect(host=h, **myuser)
    except InterfaceError:
        raise SkipTest()
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


def add_employee(conn, emp_no, first_name, last_name, gtid_executed=None):
    """
    Wait for gtid_executed and INSERT an employee.

    :param conn:
    :param emp_no:
    :param first_name:
    :param last_name:
    :param gtid_executed:
    :return:
    """
    conn.set_property(group=GROUP, mode=fabric.MODE_READWRITE)
    cur = conn.cursor()

    # Wait for gtid_executed.
    if gtid_executed:
        synchronize(cur, gtid_executed)

    cur.execute("USE employees")
    cur.execute(
        "INSERT INTO employees VALUES (%s, %s, %s)",
        (emp_no, first_name, last_name)
    )
    # We need to keep track of what we have executed in order to,
    # at least, read our own updates from a slave.
    cur.execute("SELECT @@global.gtid_executed")
    for row in cur:
        print ("Transactions executed on the master", row[0])
        return row[0]



def prepare_synchronization(cur):
    """
    Get the last executed transaction.

    :param cur:
    :return:
    """
    # We need to keep track of what we have executed so far to guarantee
    # that the employees.employees table exists at all shards.
    gtid_executed = None
    cur.execute("SELECT @@global.gtid_executed")
    for row in cur:
        gtid_executed = row[0]
    return gtid_executed


def synchronize(cur, gtid_executed):
    """
    Wait until a given transaction is replicated.

    :param cur:
    :param gtid_executed:
    :return:
    """
    # Guarantee that a slave has applied our own updates before
    # reading anything.
    cur.execute(
        "SELECT WAIT_UNTIL_SQL_THREAD_AFTER_GTIDS('%s', 0)" %
        (gtid_executed, )
    )
    for row in cur:
        print ("Had to synchronize", row, "transactions.")


def find_employee(conn, emp_no, gtid_executed):
    """
    Issue a SELECT after waiting for gtid_executed

    :param conn:
    :param emp_no:
    :param gtid_executed:
    :return:
    """
    conn.set_property(group=GROUP, mode=fabric.MODE_READONLY)
    cur = conn.cursor()
    synchronize(cur, gtid_executed)

    cur.execute("USE employees")
    cur.execute(
        "SELECT first_name, last_name FROM employees "
        "WHERE emp_no = %s", (emp_no, )
    )
    for row in cur:
        print ("Retrieved", row)


def test_fabric_query():
    #
    # Test against a replicated
    #
    # Address of the Fabric, not the host we are going to connect to.
    conn, cur = get_fabric_cursor(fabric.MODE_READWRITE)
    cur.execute("CREATE DATABASE IF NOT EXISTS employees")
    cur.execute("USE employees")
    cur.execute("DROP TABLE IF EXISTS employees")
    cur.execute(
        "CREATE TABLE employees ("
        "   emp_no INT, "
        "   first_name CHAR(40), "
        "   last_name CHAR(40)"
        ")"
    )
    # Wait for the last executed transaction
    gtid_executed = prepare_synchronization(cur)

    gtid_executed = add_employee(conn, 12, "John", "Doe", gtid_executed)
    find_employee(conn, 12, gtid_executed)
