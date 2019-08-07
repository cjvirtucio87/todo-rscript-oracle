library('config')
library('ROracle')
library('DBI')

cfg <- config::get()

kUsers <- list(
  data.frame(
    id = 1,
    name = 'foo',
    email_address = 'foo@mail.com'
  ),
  data.frame(
    id = 2,
    name = 'bar',
    email_address = 'bar@mail.com'
  ),
  data.frame(
    id = 3,
    name = 'baz',
    email_address = 'baz@mail.com'
  )
)

sql.folder <- file.path(getwd(), 'sql')
users.create.sql.path <- file.path(sql.folder, 'create_users.sql')
users.insert.sql.path <- file.path(sql.folder, 'insert_user.sql')
users.select.sql.path <- file.path(sql.folder, 'select_user.sql')

drv <- dbDriver('Oracle')
conn <- dbConnect(drv, username = cfg$oracle$username, password = cfg$oracle$password, dbname = cfg$oracle$host)

create_table <- function(conn, sql.path) {
  if (file.exists(sql.path)) {
    sql.statement <- paste(readLines(sql.path), collapse='\n')

    print(
          paste(
                c(
                  "creating table using statement:", 
                  sql.statement
                ),
                collapse='\n'))
    
    dbSendQuery(conn, sql.statement)
  }
}

insert_user <- function(conn, sql.path, data) {
  if (file.exists(sql.path)) {
    sql.statement <- paste(readLines(sql.path), collapse='\n')

    print(
          paste(
                c(
                  "inserting user into table using statement:", 
                  sql.statement
                ),
                collapse='\n'))
    
    dbSendQuery(conn, sql.statement, data)
  }
}

select_user <- function(conn, sql.path) {
  if (file.exists(sql.path)) {
    sql.statement <- paste(readLines(sql.path), collapse='\n')

    print(
          paste(
                c(
                  "selecting user with statement:", 
                  sql.statement
                ),
                collapse='\n'))
    
    return(dbSendQuery(conn, sql.statement))
  }
}

print('creating users table')

create_table(conn, users.create.sql.path)

print('inserting users')

for (user in kUsers) {
  insert_user(conn, users.insert.sql.path, user)
}

res <- select_user(conn, users.select.sql.path)

# need to fetch before the result gets populated with anything
fetch(res)

print(dbColumnInfo(res))

