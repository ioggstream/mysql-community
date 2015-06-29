import random
import mysql.connector
from mysql.connector import fabric


def prepare_synchronization(cur):
    # We need to keep track of what we have executed so far to guarantee
    # that the employees.employees table exists at all shards.
    gtid_executed = None
    cur.execute("SELECT @@global.gtid_executed")
    for row in cur:
        gtid_executed = row[0]
    return gtid_executed


def synchronize(cur, gtid_executed):
    # Guarantee that a slave has created the employees.employees table
    # before reading anything.
    cur.execute(
        "SELECT WAIT_UNTIL_SQL_THREAD_AFTER_GTIDS('%s', 0)" %
        (gtid_executed, )
    )
    cur.fetchall()

def add_employee(conn, emp_no, first_name, last_name, gtid_executed):
    conn.set_property(tables=["employees.employees"], key=emp_no,
                      mode=fabric.MODE_READWRITE)
    cur = conn.cursor()
    synchronize(cur, gtid_executed)
    cur.execute("USE employees")
    cur.execute(
        "INSERT INTO employees VALUES (%s, %s, %s)",
        (emp_no, first_name, last_name)
    )

def find_employee(conn, emp_no, gtid_executed):
    conn.set_property(tables=["employees.employees"], key=emp_no,
                      mode=fabric.MODE_READONLY)
    cur = conn.cursor()
    synchronize(cur, gtid_executed)
    cur.execute("USE employees")
    for row in cur:
        print "Had to synchronize", row, "transactions."
    cur.execute(
        "SELECT first_name, last_name FROM employees "
        "WHERE emp_no = %s", (emp_no, )
    )
    for row in cur:
        print row

def pick_shard_key():
    shard = random.randint(0, 2)
    shard_range = shard * 100000
    shard_range = shard_range if shard != 0 else shard_range + 1
    shift_within_shard = random.randint(0, 99999)
    return shard_range + shift_within_shard


# Address of the Fabric, not the host we are going to connect to.
conn = mysql.connector.connect(
    fabric={"host" : "localhost", "port" : 32274,
            "username": "admin", "password" : "adminpass"
           },
    user="webuser", password="webpass", autocommit=True
)

conn.set_property(tables=["employees.employees"], scope=fabric.SCOPE_GLOBAL,
                  mode=fabric.MODE_READWRITE)
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
gtid_executed = prepare_synchronization(cur)

conn.set_property(scope=fabric.SCOPE_LOCAL)

first_names = ["John", "Buffalo", "Michael", "Kate", "Deep", "Genesis"]
last_names = ["Doe", "Bill", "Jackson", "Bush", "Purple"]

list_emp_no = []
for count in range(10):
    emp_no = pick_shard_key()
    list_emp_no.append(emp_no)
    add_employee(conn, emp_no,
                 first_names[emp_no % len(first_names)],
                 last_names[emp_no % len(last_names)],
                 gtid_executed
    )

for emp_no in list_emp_no:
    find_employee(conn, emp_no, gtid_executed)
