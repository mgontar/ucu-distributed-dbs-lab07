config = {
  	"_id" : "rep-set",
  	"members" : [
  		{
  			"_id" : 0,
  			"host" : "shn1:27017"
  		},
  		{
  			"_id" : 1,
  			"host" : "shn2:27017"
  		}
  	]
  };
rs.initiate(config);
