import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // 🔹 Títulos principais (usados em AppBars, seções, etc.)
  static const TextStyle heading = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // 🔹 Subtítulos e seções
  static const TextStyle subheading = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // 🔹 Texto padrão
  static const TextStyle body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  // 🔹 Texto de botões
  static const TextStyle button = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
  );

  // 🔹 Estilo usado para títulos em cards, tiles, e listas
  static const TextStyle tileTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // 🔹 Estilo para subtítulos em tiles (ex: informações secundárias)
  static const TextStyle tileSubtitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  // 🔹 Texto pequeno e informativo (ex: status, datas)
  static const TextStyle tileInfo = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    color: Colors.grey,
  );

  // 🔹 Título de AppBar
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
  );

  // 🔹 Texto de destaque (ex: preços, totais)
  static const TextStyle highlight = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );
}
