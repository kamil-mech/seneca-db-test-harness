"use strict";

module.exports = {

  // options for seneca-mongo-store
  'mongo-store':{
    // uncomment if using mongo authentication
    //user:'USERMAME',
    //pass:'PASSWORD',
    host:process.env.MONGO_LINK_PORT_27017_TCP_ADDR || 'localhost',
    port:process.env.MONGO_LINK_PORT_27017_TCP_PORT || 27017,
    name:'well'
  },

  // options for seneca-postgresql-store
  'postgresql-store':{
    username:'admin',
    password:'password',
    host:process.env.POSTGRES_LINK_PORT_5432_TCP_ADDR || 'localhost',
    port:process.env.POSTGRES_LINK_PORT_5432_TCP_PORT || 5432,
    name:'admin', // Because of the way docker image works it has to be same as username
    schema:'/test/dbs/postgres.sql'
  },

  // options for seneca-redis-store
  'redis-store':{
    host:process.env.REDIS_LINK_PORT_6379_TCP_ADDR || 'localhost',
    port:process.env.REDIS_LINK_PORT_6379_TCP_PORT || 6379
  },

  // options for seneca-mysql-store
  'mysql-store':{
    host:process.env.MYSQL_LINK_PORT_3306_TCP_ADDR || 'localhost',
    port:process.env.MYSQL_LINK_PORT_3306_TCP_PORT || 3306,
    user:'root', // to keep things simple this has to be root
    password:'password',
    name:'admin',
    schema:'/test/dbs/mysql.sql'
  },

  'cassandra-store':{
    name: 'well',
    host: process.env.CASSANDRA_LINK_PORT_9160_TCP_ADDR || 'localhost',
    port: process.env.CASSANDRA_LINK_PORT_9160_TCP_PORT || 9160
  },

  'couchdb-store':{
    host: process.env.COUCHDB_LINK_PORT_12000_TCP_ADDR || 'localhost',
    port: process.env.COUCHDB_LINK_PORT_12000_TCP_PORT || 12000
  },

  'orient-store':{
    name: 'well',
    host: process.env.ORIENT_LINK_PORT_2424_TCP_ADDR || 'localhost',
    port: process.env.ORIENT_LINK_PORT_2424_TCP_PORT || 2424,
    username: 'root',
    password: '',
    options: {}
  },

  'rethink-store':{
    host: process.env.RETHINKDB_LINK_PORT_28015_TCP_ADDR || 'localhost',
    port: process.env.RETHINKDB_LINK_PORT_28015_TCP_PORT || 28015,
    authKey: "",
    db: "well"
  },
}
