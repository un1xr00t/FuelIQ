import 'package:flutter/cupertino.dart';

import 'app/fuel_iq_app.dart';
import 'data/fuel_store.dart';

void main() => runApp(FuelIqApp(store: FuelStore.local()));
