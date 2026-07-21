import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Semantic icon catalog for Kerosene.
///
/// Product screens should use this catalog instead of referencing
/// `PhosphorIcons` or Material `Icons` directly. This keeps visual meaning stable
/// even if the underlying icon pack changes.
class KeroseneIcons {
  const KeroseneIcons._();

  // Navigation
  static const IconData home = PhosphorIconsRegular.squaresFour;
  static const IconData homeFill = PhosphorIconsFill.squaresFour;
  static const IconData wallet = PhosphorIconsRegular.wallet;
  static const IconData walletFill = PhosphorIconsFill.wallet;
  static const IconData history = PhosphorIconsRegular.receipt;
  static const IconData historyFill = PhosphorIconsFill.receipt;
  static const IconData settings = PhosphorIconsRegular.fadersHorizontal;
  static const IconData menu = PhosphorIconsRegular.list;

  // Core financial actions
  static const IconData send = PhosphorIconsRegular.arrowUpRight;
  static const IconData receive = PhosphorIconsRegular.arrowDownLeft;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData internalTransfer = PhosphorIconsRegular.arrowsLeftRight;
  static const IconData onchain = PhosphorIconsRegular.link;
  static const IconData lightning = PhosphorIconsRegular.lightning;

  /// Alias used by receive hub / Lightning notification visuals.
  static const IconData bolt = lightning;
  static const IconData bitcoin = PhosphorIconsRegular.currencyBtc;

  // Activity glyph layers — rail (primary) + direction (badge) + product (pip)
  /// Primary: Lightning Network.
  static const IconData railLightning = lightning;

  /// Primary: Bitcoin on-chain.
  static const IconData railOnchain = onchain;

  /// Primary: Kerosene internal ledger.
  static const IconData railInternal = internalTransfer;

  /// Primary: cold / watch-only observed.
  static const IconData railCold = coldWallet;

  /// Direction badge: funds in.
  static const IconData dirIn = receive;

  /// Direction badge: funds out.
  static const IconData dirOut = send;

  /// Product: payment link / invoice (QR) — never internal ↔ arrows.
  static const IconData productPaymentLink = qr;

  /// @Deprecated Prefer rail pip via ActivityGlyphSpec; kept for call-sites.
  static const IconData productLinkPip = qr;
  static const IconData fee = PhosphorIconsRegular.percent;
  static const IconData creditCard = PhosphorIconsRegular.creditCard;
  static const IconData fiat = PhosphorIconsRegular.currencyDollar;
  static const IconData shoppingBag = PhosphorIconsRegular.shoppingBag;
  static const IconData shoppingCart = PhosphorIconsRegular.shoppingCart;
  static const IconData quote = PhosphorIconsRegular.receipt;
  static const IconData settlement = PhosphorIconsRegular.sealCheck;

  // Security and identity
  static const IconData security = PhosphorIconsRegular.shieldCheck;
  static const IconData shield = PhosphorIconsRegular.shield;
  static const IconData passkey = PhosphorIconsRegular.key;
  static const IconData biometric = PhosphorIconsRegular.fingerprint;
  static const IconData totp = PhosphorIconsRegular.shield;
  static const IconData shares = PhosphorIconsRegular.squaresFour;
  static const IconData device = PhosphorIconsRegular.deviceMobile;
  static const IconData business = PhosphorIconsRegular.buildings;
  static const IconData lock = PhosphorIconsRegular.lockKey;
  static const IconData unlock = PhosphorIconsRegular.lockKeyOpen;
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData userCheck = PhosphorIconsRegular.userCheck;
  static const IconData userAdd = PhosphorIconsRegular.userPlus;
  static const IconData userUnavailable = PhosphorIconsRegular.userMinus;
  static const IconData accessDenied = PhosphorIconsRegular.prohibit;
  static const IconData shieldOff = PhosphorIconsRegular.shieldSlash;
  static const IconData linkUnavailable = PhosphorIconsRegular.linkBreak;
  static const IconData binary = PhosphorIconsRegular.bracketsCurly;

  // State and feedback
  static const IconData success = PhosphorIconsRegular.checkCircle;
  static const IconData warning = PhosphorIconsRegular.warningCircle;
  static const IconData error = PhosphorIconsRegular.warning;
  static const IconData alert = PhosphorIconsRegular.warning;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData pending = PhosphorIconsRegular.clock;
  static const IconData notifications = PhosphorIconsRegular.bell;
  static const IconData notificationsOff = PhosphorIconsRegular.bellSlash;
  static const IconData timer = PhosphorIconsRegular.timer;
  static const IconData timerOff = PhosphorIconsRegular.timer;
  static const IconData serverUnavailable = PhosphorIconsRegular.hardDrives;

  static const IconData review = PhosphorIconsRegular.shieldWarning;
  static const IconData unavailable = PhosphorIconsRegular.prohibit;

  // Utilities
  static const IconData copy = PhosphorIconsRegular.copy;
  static const IconData paste = PhosphorIconsRegular.clipboard;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData closeCircle = PhosphorIconsRegular.xCircle;
  static const IconData back = PhosphorIconsRegular.arrowLeft;
  static const IconData backspace = PhosphorIconsRegular.backspace;
  static const IconData next = PhosphorIconsRegular.arrowRight;
  static const IconData up = PhosphorIconsRegular.arrowUp;
  static const IconData down = PhosphorIconsRegular.arrowDown;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData searchUnavailable =
      PhosphorIconsRegular.magnifyingGlassMinus;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData circle = PhosphorIconsRegular.circle;
  static const IconData plus = PhosphorIconsRegular.plus;
  static const IconData login = PhosphorIconsRegular.signIn;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeOff = PhosphorIconsRegular.eyeSlash;

  static const IconData refresh = PhosphorIconsRegular.arrowsClockwise;
  static const IconData trash = PhosphorIconsRegular.trash;
  static const IconData calendar = PhosphorIconsRegular.calendar;
  static const IconData externalLink = PhosphorIconsRegular.arrowSquareOut;
  static const IconData share = PhosphorIconsRegular.shareNetwork;
  static const IconData location = PhosphorIconsRegular.mapPin;

  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData chevronLeft = PhosphorIconsRegular.caretLeft;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData moveHorizontal = PhosphorIconsRegular.arrowsLeftRight;
  static const IconData trendUp = PhosphorIconsRegular.trendUp;

  // Payment interfaces
  static const IconData qr = PhosphorIconsRegular.qrCode;
  static const IconData nfc = PhosphorIconsRegular.wifiHigh;
  static const IconData scanner = PhosphorIconsRegular.scan;
  static const IconData invoice = PhosphorIconsRegular.fileText;
  static const IconData document = PhosphorIconsRegular.fileText;
  static const IconData fileVerified = PhosphorIconsRegular.fileDashed;
  static const IconData inbox = PhosphorIconsRegular.tray;
  static const IconData address = PhosphorIconsRegular.at;

  // Network and privacy
  static const IconData network = PhosphorIconsRegular.graph;
  static const IconData tor = PhosphorIconsRegular.wifiHigh;
  static const IconData privacy = PhosphorIconsRegular.eyeSlash;
  static const IconData route = PhosphorIconsRegular.wifiHigh;
  static const IconData gauge = PhosphorIconsRegular.gauge;
  static const IconData institution = PhosphorIconsRegular.bank;
  static const IconData privateMode = PhosphorIconsRegular.ghost;
  static const IconData coldWallet = PhosphorIconsRegular.snowflake;
  static const IconData group = PhosphorIconsRegular.users;
  static const IconData archive = PhosphorIconsRegular.archive;
  static const IconData database = PhosphorIconsRegular.database;
  static const IconData server = PhosphorIconsRegular.hardDrive;
  static const IconData stack = PhosphorIconsRegular.stack;
  static const IconData globe = PhosphorIconsRegular.globe;
  static const IconData sync = PhosphorIconsRegular.pulse;
  static const IconData activity = PhosphorIconsRegular.pulse;

  // Additional semantic aliases
  static const IconData wifiOff = serverUnavailable;
  static const IconData chart = trendUp;
  static const IconData contactless = nfc;
  static const IconData blocked = accessDenied;
  static const IconData undo = refresh;
  static const IconData upload = send;
  static const IconData help = info;
  static const IconData hub = network;
  static const IconData radar = network;
  static const IconData touch = biometric;
  static const IconData schedule = pending;
  static const IconData logout = externalLink;
  static const IconData contrast = circle;
  static const IconData dialpad = shares;
  static const IconData recovery = refresh;
  static const IconData linkOff = linkUnavailable;
  static const IconData cloudOff = serverUnavailable;
  static const IconData devices = device;
  static const IconData historyOff = timerOff;
  static const IconData admin = security;
  static const IconData key = passkey;
  static const IconData keyOff = shieldOff;
  static const IconData personAdd = userAdd;
  static const IconData southWest = receive;
  static const IconData northEast = send;
  static const IconData receipt = invoice;
  static const IconData verified = success;
  static const IconData cancel = closeCircle;

  // Admin/dashboard aliases
  static const IconData analytics = chart;
  static const IconData badge = userCheck;
  static const IconData dns = network;
  static const IconData language = globe;
  static const IconData layers = stack;
  static const IconData memory = database;
  static const IconData payments = creditCard;
  static const IconData phone = device;
  static const IconData privacyTip = privacy;
  static const IconData swap = moveHorizontal;
  static const IconData visibility = eye;
  static const IconData visibilityOff = eyeOff;
  static const IconData monitor = activity;
}
