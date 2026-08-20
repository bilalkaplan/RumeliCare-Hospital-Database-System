## RumeliCare Hospital Database System

RumeliCare is a relational database system for managing hospital operations. I wrote this entirely in SQL to practice database design, data relationships, and advanced SQL features.

### What It Does

The database handles the core flow of a hospital. It stores records for patients, doctors, and departments. It tracks appointments, medical examinations, prescriptions, and billing. I also included stored procedures for common tasks (like booking an appointment), triggers for automatic cost calculations, and views for generating daily reports.

### Run It

You just need MySQL or MariaDB installed. 
Import the SQL file to your local database:
mysql -u your_username -p < RumeliCare.sql
This script will automatically create the `RumeliCare` database, set up all the tables with their relations, and initialize the triggers and procedures.

### Built With

- SQL (MySQL / MariaDB)
