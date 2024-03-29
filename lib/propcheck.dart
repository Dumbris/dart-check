// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library propcheck;

import 'dart:io';
import 'dart:math';
import 'package:enumerators/enumerators.dart';

part 'src/products.dart';

class Property {
  final Enumeration<_Product> enumeration;
  final Function property;
  Property(this.enumeration, this.property);
}

Property forall(Enumeration enumeration, bool property(x)) =>
    new Property(_P1.enumerate(enumeration),
                 (_P1 p) => property(p.proj1));

Property forall2(Enumeration enumeration1, Enumeration enumeration2,
                 bool property(x, y)) =>
    new Property(_P2.enumerate(enumeration1, enumeration2),
                 (_P2 p) => property(p.proj1, p.proj2));

Property forall3(Enumeration enumeration1, Enumeration enumeration2,
                 Enumeration enumeration3, bool property(x, y, z)) =>
    new Property(_P3.enumerate(enumeration1, enumeration2, enumeration3),
                 (_P3 p) => property(p.proj1, p.proj2, p.proj3));

Property forall4(Enumeration enumeration1, Enumeration enumeration2,
                 Enumeration enumeration3, Enumeration enumeration4,
                 bool property(x, y, z, w)) =>
    new Property(_P4.enumerate(enumeration1, enumeration2, enumeration3,
                               enumeration4),
                 (_P4 p) => property(p.proj1, p.proj2, p.proj3, p.proj4));

abstract class Check {
  final bool quiet;

  Check(this.quiet);

  check(Property);

  void display(String message) {
    if (!quiet) {
      stdout.write("\r\u001b[K$message");
    }
  }

  void clear() => display('');

  static String _errorMessage(int counter, _Product prod) {
    final res = new StringBuffer("falsified after $counter tests\n");
    final args = prod.toStrings();
    for (int i = 0; i < args.length; i++) {
      res.write("  argument ${i+1}: ${args[i]}\n");
    }
    return res.toString();
  }
}

class SmallCheck extends Check {
  final int depth;

  SmallCheck({depth: 4, quiet: false})
      : this.depth = depth
      , super(quiet);

  void check(Property property) {
    final parts = property.enumeration.parts.take(depth + 1);
    int total = 0;
    for (final part in parts) {
      total += part.length;
    }

    int counter = 0;
    int currentDepth = 0;
    for (final part in parts) {
      int card = part.length;
      for(int i = 0; i < card; i++) {
        display("${counter+1}/$total (depth $currentDepth: ${i+1}/$card)");
        _Product arg = part[i];
        if (!property.property(arg)) {
          clear();
          throw Check._errorMessage(counter + 1, arg);
        }
        counter++;
      }
      currentDepth++;
    }
    clear();
  }
}

class QuickCheck extends Check {
  static const MAX_INT = ((1 << 32) - 1);
  final int seed;
  final int maxSize;

  QuickCheck({seed: 0, maxSuccesses: 100, maxSize: 100, quiet: false})
      : this.seed = seed
      , this.maxSize = maxSize
      , super(quiet);

  void check(Property property) {
    final random = new Random(seed);
    final nonEmptyParts = <Pair<int,Finite>>[];
    int counter = 0;
    final iterator = property.enumeration.parts.iterator;
    while (counter <= maxSize && iterator.moveNext()) {
      final part = iterator.current;
      if (part.length > 0) {
        nonEmptyParts.add(new Pair(counter, part));
      }
      counter++;
    }
    int numParts = nonEmptyParts.length;
    for (int i = 0; i < numParts; i++) {
      final pair = nonEmptyParts[i];
      final size = pair.fst;
      final part = pair.snd;
      display("${i+1}/$numParts (size $size)");

      // TODO: replace by randInt when it handles bigints
      int maxIndex = part.length - 1;
      int index;
      if (maxIndex == 0) {
        index = 0;
      } else if (maxIndex < MAX_INT) {
        index = random.nextInt(maxIndex);
      } else {
        // poor resolution, would need real bigint rng
        int numerator = random.nextInt(MAX_INT);
        index = ((part.length-1) * numerator) ~/ MAX_INT;
      }

      _Product arg = part[index];
      if (!property.property(arg)) {
        clear();
        throw Check._errorMessage(i + 1, arg);
      }
    }
    clear();
  }
}
