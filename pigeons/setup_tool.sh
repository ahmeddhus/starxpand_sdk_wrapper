#!/usr/bin/env bash
dart run pigeon \
  --input pigeons/starxpand.dart \
  --dart_out lib/src/pigeon.g.dart \
  --kotlin_out android/src/main/kotlin/dev/orioletech/starxpand_sdk_wrapper/Pigeon.g.kt \
  --kotlin_package dev.orioletech.starxpand_sdk_wrapper \
  --swift_out ios/Classes/Pigeon.g.swift
