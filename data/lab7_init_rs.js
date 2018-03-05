config = {
  	"_id" : "cfg-set",
	"configsvr": true,
  	"members" : [
  		{
  			"_id" : 0,
  			"host" : "cs1:27019"
  		}
  	]
  };
rs.initiate(config);
