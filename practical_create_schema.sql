/* ***************************************************** **
   practical_create_schema.sql
   
   Companion script for Practical Oracle SQL, Apress 2020
   by Kim Berg Hansen, https://www.kibeha.dk
   Use at your own risk
   *****************************************************
   
   Creation of the user/schema PRACTICAL
   Granting the necessary privileges to this schema
   
   To be executed as a DBA user
** ***************************************************** */

create user C##practical
   identified by practical
   default tablespace users
   temporary tablespace temp;

alter user C##practical quota unlimited on users;

grant create session    to C##practical;
grant create table      to C##practical;
grant create view       to C##practical;
grant create type       to C##practical;
grant create procedure  to C##practical;

/* ***************************************************** */
