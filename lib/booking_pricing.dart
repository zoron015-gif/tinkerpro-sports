double calculateExtraPlayerCharge({
  required int players,
  required int includedPlayers,
  required double feePerExtraPlayer,
}) {
  if (players < 0 || includedPlayers < 0 || feePerExtraPlayer < 0) {
    throw ArgumentError('Player counts and fees must not be negative.');
  }
  return ((players - includedPlayers).clamp(0, players) * feePerExtraPlayer)
      .toDouble();
}
