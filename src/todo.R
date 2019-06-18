library('ROracle')
library('DBI')

sql.folder <- file.path(getwd(), 'sql')
users.create.sql.path <- file.path(sql.folder, 'create_users.sql')

drv <- dbDriver('Oracle')
conn <- dbConnect(drv, username = 'system', password = 'set4now', dbname = 'todo-oracle')

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

create_table(conn, users.create.sql.path)

