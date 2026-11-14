"""Build the Pennsylvania station catalog from a Geofabrik OSM PBF extract."""

import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import re

import osmium

SOURCE = "https://download.geofabrik.de/north-america/us/pennsylvania.html"
OCTANE = re.compile(r"octane_[1-9][0-9]{1,2}")
FUEL_TYPES = (
    "regular", "midgrade", "premium", "gasoline", "petrol",
    "diesel", "HGV_diesel", "biodiesel", "e10", "e15", "e85", "e0", "lpg", "cng",
)


def fuel_grades(tags):
    octanes = sorted(
        (tag.k[5:] for tag in tags
         if tag.v == "yes" and tag.k.startswith("fuel:") and OCTANE.fullmatch(tag.k[5:])),
        key=lambda key: int(key[7:]),
    )
    return octanes + [key for key in FUEL_TYPES if tags.get(f"fuel:{key}") == "yes"]


def address(tags, *, full=False):
    number = tags.get("addr:housenumber")
    street = tags.get("addr:street")
    if full and not (number and street):
        return ""
    line = " ".join(value for value in (number, street) if value)
    return ", ".join(
        value for value in (line, tags.get("addr:city"), tags.get("addr:postcode"))
        if value
    )


def cell(latitude, longitude):
    return math.floor(latitude * 1000), math.floor(longitude * 1000)


def inside(latitude, longitude, ring):
    crossings = 0
    for (ay, ax), (by, bx) in zip(ring, ring[1:]):
        if (ay > latitude) != (by > latitude):
            crossings += longitude < ax + (bx - ax) * (latitude - ay) / (by - ay)
    return crossings % 2 == 1


def fill_addresses(extract, records, footprints, addressed):
    by_cell = defaultdict(list)
    targets = {}
    for record in records:
        if record["id"] in addressed:
            continue
        identifier = record["id"]
        latitude, longitude = record["latitude"], record["longitude"]
        ring = footprints.get(identifier, [])
        points = ring or [(latitude, longitude)]
        south, west = cell(min(y for y, _ in points) - 0.000003,
                           min(x for _, x in points) - 0.000003)
        north, east = cell(max(y for y, _ in points) + 0.000003,
                           max(x for _, x in points) + 0.000003)
        targets[identifier] = (record, ring, set())
        for y in range(south, north + 1):
            for x in range(west, east + 1):
                by_cell[y, x].append(identifier)

    processor = osmium.FileProcessor(extract, osmium.osm.NODE)
    processor.with_filter(osmium.filter.KeyFilter("addr:housenumber"))
    for node in processor:
        if not node.location.valid():
            continue
        latitude, longitude = node.location.lat, node.location.lon
        value = address(node.tags, full=True)
        if not value:
            continue
        for identifier in by_cell.get(cell(latitude, longitude), ()):
            record, ring, matches = targets[identifier]
            same_point = (abs(latitude - record["latitude"]) <= 0.000003
                          and abs(longitude - record["longitude"]) <= 0.000003)
            if same_point or (ring and inside(latitude, longitude, ring)):
                matches.add(value)

    filled = 0
    for record, _, matches in targets.values():
        if len(matches) == 1:
            record["address"] = next(iter(matches))
            filled += 1
    return filled


def station(obj, kind, identifier, latitude, longitude):
    tags = obj.tags
    if tags.get("amenity") != "fuel" or tags.get("access") in {"private", "no"}:
        return None
    record = {
        "id": f"{kind}/{identifier}",
        "name": tags.get("name") or tags.get("brand") or "Fuel station",
        "brand": tags.get("brand", ""),
        "address": address(tags),
        "latitude": round(latitude, 6),
        "longitude": round(longitude, 6),
    }
    grades = fuel_grades(tags)
    if grades:
        record["fuelGrades"] = grades
    return record


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
    footprints = {}
    addressed = set()
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
            if address(obj.tags, full=True):
                addressed.add(record["id"])
            if obj.is_area() and obj.num_rings() == (1, 0):
                footprints[record["id"]] = [(p.lat, p.lon) for p in points]
    if not records or len({record["id"] for record in records}) != len(records):
        parser.error("Catalog is empty or contains duplicate source IDs.")
    records.sort(key=lambda record: record["id"])
    filled = fill_addresses(args.extract, records, footprints, addressed)
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(
            {"version": 1, "source": SOURCE, "asOf": timestamp, "stations": records},
            ensure_ascii=False, separators=(",", ":"),
        ) + "\n",
        encoding="utf-8",
    )
    temporary.replace(args.output)
    print(f"{len(records)} stations as of {timestamp}, {filled} addresses matched")


if __name__ == "__main__":
    main()
