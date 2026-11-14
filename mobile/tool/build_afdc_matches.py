"""Match public DOT/AFDC fuel records to FuelIQ's Pennsylvania catalog."""

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen

SOURCE = ("https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/"
          "Alternative_Fueling_Stations/FeatureServer/0/query")
FUELS = {"E85": "e85", "BD": "biodiesel", "LPG": "lpg", "CNG": "cng"}
FIELDS = ("id,fuel_type_code,street_address,latitude,longitude,date_last_confirmed,"
          "restricted_access,unverified,state,country,access_code,status_code")
STREET_WORDS = {"street": "st", "road": "rd", "avenue": "ave", "boulevard": "blvd",
                "drive": "dr", "highway": "hwy", "lane": "ln", "route": "rt"}


def fetch():
    query = urlencode({
        "where": "state='PA' AND country='US' AND access_code='public' AND "
                 "status_code='E' AND fuel_type_code IN ('E85','BD','LPG','CNG')",
        "outFields": FIELDS, "returnGeometry": "false", "f": "json",
        "orderByFields": "id",
    })
    for attempt in range(3):
        try:
            with urlopen(f"{SOURCE}?{query}", timeout=25) as response:
                return json.load(response)
        except HTTPError as error:
            if error.code not in (429, 500, 502, 503, 504) or attempt == 2:
                raise
            retry_after = error.headers.get("Retry-After")
            if retry_after:
                raise  # Leave longer throttling windows to the next manual run.
        except (URLError, TimeoutError):
            if attempt == 2:
                raise
        time.sleep(2 ** attempt)


def street(value):
    words = re.findall(r"[a-z0-9]+", value.lower().split(",")[0])
    if not words or not words[0].isdigit():
        return ""
    return " ".join(STREET_WORDS.get(word, word) for word in words)


def distance_m(a, b):
    lat, lon = map(math.radians, (a["latitude"], a["longitude"]))
    other_lat, other_lon = map(math.radians, (b["latitude"], b["longitude"]))
    h = (math.sin((lat - other_lat) / 2) ** 2
         + math.cos(lat) * math.cos(other_lat) * math.sin((lon - other_lon) / 2) ** 2)
    return 12_742_000 * math.asin(math.sqrt(min(1, h)))


def match(catalog, data):
    if data.get("error") or data.get("exceededTransferLimit") or not data.get("features"):
        raise ValueError("DOT response is empty, incomplete, or returned an error.")
    by_street = defaultdict(list)
    for station in catalog["stations"]:
        key = street(station["address"])
        if key:
            by_street[key].append(station)
    matches = defaultdict(list)
    seen = set()
    for feature in data["features"]:
        row = feature["attributes"]
        identifier = row["id"]
        fuel = FUELS.get(row["fuel_type_code"])
        if type(identifier) is not int or identifier <= 0 or identifier in seen or not fuel:
            raise ValueError(f"Unexpected DOT record: {identifier!r}")
        seen.add(identifier)
        if (row["state"], row["country"], row["access_code"], row["status_code"]) != (
                "PA", "US", "public", "E"):
            raise ValueError(f"DOT record outside requested scope: {identifier}")
        if row["restricted_access"] != 0 or row["unverified"] != 0:
            continue
        if not all(type(row[field]) in (float, int) and abs(row[field]) <= bound
                   for field, bound in (("latitude", 90), ("longitude", 180))):
            raise ValueError(f"Invalid coordinates for DOT record {identifier}")
        candidates = [station for station in by_street[street(row["street_address"])]
                      if distance_m(station, row) <= 100]
        if len(candidates) != 1:
            continue
        confirmed = row["date_last_confirmed"]
        if type(confirmed) is not int:
            continue
        date = datetime.fromtimestamp(confirmed / 1000, timezone.utc).date().isoformat()
        matches[candidates[0]["id"]].append({
            "id": identifier, "fuel": fuel, "confirmed": date,
        })
    return dict(sorted(matches.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    records = match(catalog, fetch())
    result = {"catalogAsOf": catalog["asOf"], "stations": records}
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    temporary.replace(args.output)
    print(f"Matched {sum(map(len, records.values()))} DOT records to {len(records)} stations.")


if __name__ == "__main__":
    main()
