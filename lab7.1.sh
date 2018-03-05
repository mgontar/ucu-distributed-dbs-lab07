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
