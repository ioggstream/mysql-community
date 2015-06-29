"""
    From http://dev.mysql.com/doc/mysql-utilities/1.5/en/fabric-quick-start-replication.html
"""
import mysql.connector
from mysql.connector import fabric


def add_employee(conn, emp_no, first_name, last_name):
    conn.set_property(group="my_group", mode=fabric.MODE_READWRITE)
    cur = conn.cursor()
    cur.execute("USE employees")
    cur.execute(
        "INSERT INTO employees VALUES (%s, %s, %s)",
        (emp_no, first_name, last_name)
    )
    # We need to keep track of what we have executed in order to,
    # at least, read our own updates from a slave.
    cur.execute("SELECT @@global.gtid_executed")
    for row in cur:
        print "Transactions executed on the master", row[0]
        return row[0]


def find_employee(conn, emp_no, gtid_executed):
    conn.set_property(group="my_group", mode=fabric.MODE_READONLY)
    cur = conn.cursor()
    # Guarantee that a slave has applied our own updates before
    # reading anything.
    cur.execute(
        "SELECT WAIT_UNTIL_SQL_THREAD_AFTER_GTIDS('%s', 0)" %
        (gtid_executed, )
    )
    for row in cur:
        print "Had to synchronize", row, "transactions."
    cur.execute("USE employees")
    cur.execute(
        "SELECT first_name, last_name FROM employees "
        "WHERE emp_no = %s", (emp_no, )
    )
    for row in cur:
        print "Retrieved", row


def test_fabric_query():
    # Address of the Fabric, not the host we are going to connect to.
    conn = mysql.connector.connect(
        fabric={"host": "localhost", "port": 32274,
                "username": "admin", "password": "adminpass"
                },
        user="webuser", password="webpass", autocommit=True
    )

    conn.set_property(group="my_group", mode=fabric.MODE_READWRITE)
    cur = conn.cursor()
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

    gtid_executed = add_employee(conn, 12, "John", "Doe")
    find_employee(conn, 12, gtid_executed)
