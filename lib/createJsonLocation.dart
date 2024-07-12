
createJsonLocation (latitude, longitude){
  return {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "properties": {},
        "geometry": {
          "coordinates": [longitude, latitude],
          "type": "Point"
        }
      }
    ]
  };
}