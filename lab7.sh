#!/bin/bash

reset

printf "Clear previouse setup\n"

sudo docker stop rsn1 rsn2 rsn3
sudo docker rm rsn1 rsn2 rsn3
sudo docker stop cs1 shn1 shn2 rtn1
sudo docker rm cs1 shn1 shn2 rtn1
sudo docker network rm rsn-net


# Task 1: init
printf "Task 1: init sharding replica set\n"

sudo docker pull mongo
sudo docker network create rsn-net
printf "Creating config service\n"
sudo docker run -d -v /home/mgontar/dev/lab7/data:/root/data \
-p 30001:27019 --name cs1 --net rsn-net \
mongo mongod --configsvr --port 27019 --replSet cfg-set 
#--bind_ip localhost,172.19.0.2
sleep 10s
#cs1ip="$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cs1)"
#--host $cs1ip
sudo docker exec -it cs1 mongo --port 27019 --quiet --eval "load('root/data/lab7_init_rs.js');"
sleep 20s
printf "Creating shards\n"
sudo docker run -d -v /home/mgontar/dev/lab7/data:/root/data \
-p 30002:27017 --name shn1 --net rsn-net mongo mongod --shardsvr --port 27017 --replSet rep-set
sudo docker run -d -p 30003:27017 --name shn2 --net rsn-net mongo mongod --shardsvr --port 27017 --replSet rep-set
sleep 10s
sudo docker exec -it shn1 mongo --quiet --eval "load('root/data/lab7_init_sh.js');"
sleep 20s
printf "Creating router\n"
sudo docker run -d -p 30004:27017 --name rtn1 --net rsn-net \
mongo mongos --configdb cfg-set/cs1:27019
sleep 10s

printf "Enabling sharding\n"
sudo docker exec -it rtn1 mongo --quiet --eval \
"sh.addShard('rep-set/shn1:27017,shn2:27017');
db = (new Mongo('localhost:27017')).getDB('test');
sh.enableSharding('test');"
sleep 20s

sudo docker exec -it rtn1 mongo --quiet --eval \
"sh.addShardToZone('shn1', 'CHP');
sh.addShardToZone('shn2', 'EXP');
sh.shardCollection('test.orders', {'cost':1});
sh.addTagRange('test.orders', { cost: 0 }, { cost: 500 }, 'CHP');
sh.addTagRange('test.orders', { cost: 501 }, { cost: 1000000 }, 'EXP');
sh.shardCollection('test.products', {'producer':1});
sh.startBalancer();
sh.getBalancerState();
sh.isBalancerRunning();"
sleep 20s
printf "Sharding status\n"
sudo docker exec -it rtn1 mongo --quiet --eval "sh.status();"
printf "Init database\n"

sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.insert({id: 'DFHG21', producer : 'Apple', name : 'iPhone4', price:400});
db.products.insert({id: 'LFDF32', producer : 'Apple', name : 'iPhone6', price:900});
db.products.insert({id: 'MDSA13', producer : 'Samsung', name : 'Galaxy S5', price:800});
db.products.find();
db.orders.insert({productId : 'DFHG21', customer: 'Asdnk Lfdm', cost: 400});
db.orders.insert({productId : 'LFDF32', customer: 'Ddkk Sasdjk', cost: 900});
db.orders.insert({productId : 'LFDF32', customer: 'Ndnf Lldfn', cost: 900});
db.orders.find();
db.products.createIndex({name: 1, price:1});
db.orders.createIndex({customer: 1, cost:1});"

printf "Sharding distribution\n"
sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.getShardDistribution();
db.orders.getShardDistribution();"


# Task 2: test sharding with shn2 off
printf "Task 2: test sharding with shn2 off\n"
printf "Disconnect shn2\n"
sudo docker network disconnect rsn-net shn2
sleep 20s
printf "Write items for shard shn2\n"
sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.insert([{id: 'MXSD32', producer : 'Zzapp', name : 'zapPhone99', price:100},
{id: 'HFDG12', producer : 'Yappy', name : 'yPhone199', price:200}], 
{ writeConcern: { w: 0, j: false } });
db.orders.insert([{productId : 'LFDF32', customer: 'Cdsmm Dmdss', cost: 900},
{productId : 'MDSA13', customer: 'Jfkf Ljdsk', cost: 800}], 
{ writeConcern: { w: 0, j: false } });"

printf "Write items for shard shn1\n"
sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.insert([{id: 'HJDS98', producer : 'Apple', name : 'iPhone3', price:50},{id: 'LKDS12', producer : 'BQ', name : 'bPad', price:300}], { writeConcern: { w: 0, j: false } });
db.orders.insert([{productId : 'MXSD32', customer: 'Cdsmm Dmdss', cost: 100}, {productId : 'HFDG12', customer: 'Jfkf Ljdsk', cost: 200}],{ writeConcern: { w: 0, j: false } });"

sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.insert([{id: 'HJDS98', producer : 'Apple', name : 'iPhone3', price:50}],
{ writeConcern: { w: 0, j: false } });"

printf "Find items from shard shn1\n"
sudo docker exec -it rtn1 mongo --quiet --eval "db.products.find({producer : 'Apple'}).readPref('nearest');"
sudo docker exec -it rtn1 mongo --quiet --eval "db.orders.find({cost: 100}).readPref('nearest');"

printf "Find items from shard shn2\n"
sudo docker exec -it rtn1 mongo --quiet --eval "db.products.find({producer : 'Zzapp'}).readPref('nearest');"
sudo docker exec -it rtn1 mongo --quiet --eval "db.orders.find({cost: 800}).readPref('nearest');"

# Task 3: test sharding with shn2 on
printf "Task 3: test sharding with shn2 on\n"
printf "Connect shn2\n"
sudo docker network connect rsn-net shn2
sleep 20s

printf "Write items for shard shn2\n"
sudo docker exec -it rtn1 mongo --quiet --eval \
"db.products.insert([{id: 'MXSD32', producer : 'Zzapp', name : 'zapPhone99', price:100},
{id: 'HFDG12', producer : 'Yappy', name : 'yPhone199', price:200}], 
{ writeConcern: { w: 0, j: false } });
db.orders.insert([{productId : 'LFDF32', customer: 'Cdsmm Dmdss', cost: 900},
{productId : 'MDSA13', customer: 'Jfkf Ljdsk', cost: 800}], 
{ writeConcern: { w: 0, j: false } });"

printf "Find items from shard shn2\n"
sudo docker exec -it rtn1 mongo --quiet --eval "db.products.find({producer : 'Zzapp'}).readPref('nearest');"
sudo docker exec -it rtn1 mongo --quiet --eval "db.orders.find({cost: 800}).readPref('nearest');"
