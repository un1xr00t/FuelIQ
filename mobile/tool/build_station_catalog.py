"""Build the Pennsylvania station catalog from a Geofabrik OSM PBF extract."""

import argparse
import json
from pathlib import Path

import osmium

SOURCE = "https://download.geofabrik.de/north-america/us/pennsylvania.html"


def station(obj, kind, identifier, latitude, longitude):
    tags = obj.tags
    if tags.get("amenity") != "fuel" or tags.get("access") in {"private", "no"}:
        return None
    street = " ".join(
        value for key in ("addr:housenumber", "addr:street") if (value := tags.get(key))
    )
    address = ", ".join(
        value for value in (street, tags.get("addr:city"), tags.get("addr:postcode"))
        if value
    )
    return {
        "id": f"{kind}/{identifier}",
        "name": tags.get("name") or tags.get("brand") or "Fuel station",
        "brand": tags.get("brand", ""),
        "address": address,
        "latitude": round(latitude, 6),
        "longitude": round(longitude, 6),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extract", help="Pennsylvania Geofabrik .osm.pbf")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with osmium.io.Reader(args.extract) as reader:
        timestamp = reader.header().get("osmosis_replication_timestamp")
    if not timestamp:
        parser.error("The extract is missing its replication timestamp.")
    records = []
    processor = osmium.FileProcessor(args.extract).with_locations().with_areas()
    processor.with_filter(osmium.filter.TagFilter(("amenity", "fuel")))
    for obj in processor:
        if obj.is_node() and obj.location.valid():
            record = station(obj, "node", obj.id, obj.location.lat, obj.location.lon)
        elif obj.is_area():
            ring = next(iter(obj.outer_rings()), None)
            points = [node.location for node in ring if node.location.valid()] if ring else []
            if not points:
                continue
            latitude = (min(p.lat for p in points) + max(p.lat for p in points)) / 2
            longitude = (min(p.lon for p in points) + max(p.lon for p in points)) / 2
            kind = "way" if obj.from_way() else "relation"
            record = station(obj, kind, obj.orig_id(), latitude, longitude)
        else:
            continue
        if record:
            records.append(record)
    if not records or len({record["id"] for record in records}) != len(records):
        parser.error("Catalog is empty or contains duplicate source IDs.")
    records.sort(key=lambda record: record["id"])
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(
            {"version": 1, "source": SOURCE, "asOf": timestamp, "stations": records},
            ensure_ascii=False, separators=(",", ":"),
        ) + "\n",
        encoding="utf-8",
    )
    temporary.replace(args.output)
    print(f"{len(records)} stations as of {timestamp}")


if __name__ == "__main__":
    main()
