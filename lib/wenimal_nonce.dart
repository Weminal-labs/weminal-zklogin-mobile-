import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:sui/sui.dart';
import 'package:zklogin/zk_login_store.dart';

import 'constants.dart';
import 'wenimal_poseidon.dart';

const int NONCE_LENGTH = 27; //27

Uint8List randomBytes([int bytesLength = 32]) {
  final Random random = Random.secure();
  return Uint8List.fromList(
      List<int>.generate(bytesLength, (_) => random.nextInt(256)));
}

BigInt toBigIntBE(Uint8List bytes) {
  String hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  if (hex.isEmpty) {
    return BigInt.zero;
  }
  return BigInt.parse(hex, radix: 16);
}

String generateRandomness() {
  Uint8List bytes = randomBytes(16);
  BigInt bigInt = toBigIntBE(bytes);
  return bigInt.toString();
}

BigInt createRandomness() {
  Uint8List bytes = randomBytes(16);
  return toBigIntBE(bytes);
}

Future<String> generateNonce() async {
  SuiClient client = SuiClient(Constants.baseNet);
  ZkLoginStore.randomness = createRandomness();
  ZkLoginStore.ephemeralKey = Ed25519Keypair();
  var publicKey = ZkLoginStore.ephemeralKey.getPublicKey();
  var publicKeyBytes = toBigIntBE(publicKey.toSuiBytes());
  final eph_public_key_0 = publicKeyBytes ~/ BigInt.from(2).pow(128);
  final eph_public_key_1 = publicKeyBytes % BigInt.from(2).pow(128);

  var getEpoch = await client.getLatestSuiSystemState();
  var epoch = getEpoch.epoch;
  ZkLoginStore.maxEpoch = int.parse(epoch) + 10;

  var bigNum = poseidonHash([
    eph_public_key_0,
    eph_public_key_1,
    BigInt.from(ZkLoginStore.maxEpoch),
    ZkLoginStore.randomness
  ]);
  var Z = toBigEndianBytes(bigNum, 20);
  var nonce = base64Url.encode(Z);
  nonce = nonce.replaceAll('=', '');
  if (nonce.length != NONCE_LENGTH) {
    throw Exception(
        'Length of nonce $nonce (${nonce.length}) is not equal to $NONCE_LENGTH');
  }
  return nonce;
}
