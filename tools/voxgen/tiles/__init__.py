"""The tile modules. Importing this package registers every tile in common.TILES (each module
calls @tile / register at import time); generate.py then writes them out.

Modules per category (later ones build on the helpers of earlier ones):
- ground: ground (roads, pavements, squares, nature, water, rail, tram, base helpers),
  ground_extra (markings, parking, gentle slopes, stairs, tunnels, pools, waterfront, ...),
  ground_bridges_curves (bridges, cobbles, rounded curves), ground_rising_curves (curves with
  height), ground_junction (motorway exits and on-ramps)
- buildings: buildings (toolkit and classic styles), building_styles (most other styles),
  building_roofs (roof coverings, battlements, radio tower, car park), building_campus
  (university, college, offices with a colonnade)
- details: details, details_extra (facade and roof parts)
- props: props, props_extra (street furniture, signs, trees, fences, playground, ...)
- mixed later additions: extras_business_paths (business units, industrial fencing, paths,
  hills, verges, footbridges), extras_shops_lanes (themed shops, tunnel troughs, tram and
  bus lanes, luxury apartments, green roofs), traffic_lights_industry (traffic lights in
  every state, sheds, warehouses, factories)

The import order below is the registration order and must stay as it is.
"""
from . import ground  # noqa: F401
from . import ground_extra  # noqa: F401
from . import ground_bridges_curves  # noqa: F401
from . import ground_rising_curves  # noqa: F401
from . import ground_junction  # noqa: F401
from . import buildings  # noqa: F401
from . import building_styles  # noqa: F401
from . import building_roofs  # noqa: F401
from . import details  # noqa: F401
from . import details_extra  # noqa: F401
from . import props  # noqa: F401
from . import props_extra  # noqa: F401
from . import extras_business_paths  # noqa: F401
from . import extras_shops_lanes  # noqa: F401
from . import building_campus  # noqa: F401
from . import traffic_lights_industry  # noqa: F401
