import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:komodo_dex/utils/log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komodo_dex/blocs/coins_bloc.dart';
import 'package:komodo_dex/model/coin.dart';
import 'package:komodo_dex/model/coin_balance.dart';
import 'package:komodo_dex/utils/utils.dart';

class CexProvider extends ChangeNotifier {
  CexProvider() {
    _updateTickersList();
    _updateRates();

    cexPrices.linkProvider(this);
  }

  bool isChartAvailable(String pair) {
    return _findChain(pair) != null;
  }

  Future<ChartData> getCandles(
    String pair, [
    double duration = 5.0 * 60,
  ]) async {
    if (_charts[pair] == null) {
      await _updateChart(pair);
    } else if (DateTime.now().millisecondsSinceEpoch - _charts[pair].updated >
        duration * 1000) {
      await _updateChart(pair);
    }

    return _charts[pair];
  }

  double getUsdPrice(String abbr) => cexPrices.getUsdPrice(abbr);

  String convert(
    double volume, {
    String from,
    String to,
    bool hidden = false,
  }) =>
      cexPrices.convert(volume, from: from, to: to, hidden: hidden);

  List<String> get fiatList => cexPrices.fiatList;
  String get currency => cexPrices.currencies[cexPrices.activeCurrency];
  String get selectedFiat => cexPrices.selectedFiat;
  set selectedFiat(String value) => cexPrices.selectedFiat = value;

  void switchCurrency() {
    int idx = cexPrices.activeCurrency;
    idx++;
    if (idx + 1 > cexPrices.currencies.length) idx = 0;
    cexPrices.activeCurrency = idx;
  }

  void notify() => notifyListeners();

  @override
  void dispose() {
    super.dispose();
    cexPrices.unlinkProvider(this);
  }

  final String _chartsUrl = 'http://komodo.live:3333/api/v1/ohlc';
  final String _tickersListUrl =
      'http://komodo.live:3333/api/v1/ohlc/tickers_list';
  final Map<String, ChartData> _charts = {}; // {'BTC-USD': ChartData(),}
  bool _updatingChart = false;
  List<String> _tickers;

  void _updateRates() => cexPrices.updateRates();

  List<String> _getTickers() {
    if (_tickers != null) return _tickers;

    _updateTickersList();
    return _tickersFallBack;
  }

  Future<void> _updateTickersList() async {
    http.Response _res;
    String _body;
    try {
      _res = await http.get(_tickersListUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log('cex_provider', 'Fetching tickers timed out');
          throw 'Fetching tickers timed out';
        },
      );
      _body = _res.body;
    } catch (e) {
      Log('cex_provider', 'Failed to fetch tickers list: $e');
      rethrow;
    }

    List<dynamic> json;
    try {
      json = jsonDecode(_body);
    } catch (e) {
      Log('cex_provider', 'Failed to parse tickers json: $e');
      rethrow;
    }

    if (json != null) {
      _tickers =
          json.map<String>((dynamic ticker) => ticker.toString()).toList();
      notifyListeners();
    }
  }

  Future<void> _updateChart(String pair) async {
    if (_updatingChart) return;

    final List<ChainLink> chain = _findChain(pair);
    if (chain == null) throw 'No chart data available';

    Map<String, dynamic> json0;
    Map<String, dynamic> json1;

    _updatingChart = true;
    if (_charts[pair] != null) {
      _charts[pair].status = ChartStatus.fetching;
    }
    try {
      json0 = await _fetchChartData(chain[0]);
      if (chain.length > 1) {
        json1 = await _fetchChartData(chain[1]);
      }
    } catch (_) {
      _updatingChart = false;
      if (_charts[pair] != null) {
        _charts[pair]
          ..status = ChartStatus.error
          ..updated = DateTime.now().millisecondsSinceEpoch;
      }
      rethrow;
    }

    _updatingChart = false;

    if (json0 == null) return;
    if (chain.length > 1 && json1 == null) return;

    final Map<String, List<CandleData>> data = {};
    json0.forEach((String duration, dynamic list) {
      final List<CandleData> _durationData = [];

      for (var candle in list) {
        double open = chain[0].reverse
            ? 1 / candle['open'].toDouble()
            : candle['open'].toDouble();
        double high = chain[0].reverse
            ? 1 / candle['high'].toDouble()
            : candle['high'].toDouble();
        double low = chain[0].reverse
            ? 1 / candle['low'].toDouble()
            : candle['low'].toDouble();
        double close = chain[0].reverse
            ? 1 / candle['close'].toDouble()
            : candle['close'].toDouble();
        double volume = chain[0].reverse
            ? candle['quote_volume'].toDouble()
            : candle['volume'].toDouble();
        double quoteVolume = chain[0].reverse
            ? candle['volume'].toDouble()
            : candle['quote_volume'].toDouble();
        final int timestamp = candle['timestamp'];

        if (chain.length > 1) {
          dynamic secondCandle;
          try {
            secondCandle =
                json1[duration].toList().firstWhere((dynamic candle) {
              return candle['timestamp'] == timestamp;
            });
          } catch (_) {}

          if (secondCandle == null) continue;

          final double secondOpen = chain[1].reverse
              ? 1 / secondCandle['open'].toDouble()
              : secondCandle['open'].toDouble();
          final double secondHigh = chain[1].reverse
              ? 1 / secondCandle['high'].toDouble()
              : secondCandle['high'].toDouble();
          final double secondLow = chain[1].reverse
              ? 1 / secondCandle['low'].toDouble()
              : secondCandle['low'].toDouble();
          final double secondClose = chain[1].reverse
              ? 1 / secondCandle['close'].toDouble()
              : secondCandle['close'].toDouble();

          final bool reversed =
              chain[0].base == pair.split('-')[1].toLowerCase() ||
                  chain[0].rel == pair.split('-')[1].toLowerCase();

          open = reversed ? 1 / (open * secondOpen) : open * secondOpen;
          close = reversed ? 1 / (close * secondClose) : close * secondClose;
          high = reversed ? 1 / (high * secondHigh) : high * secondHigh;
          low = reversed ? 1 / (low * secondLow) : low * secondLow;
          volume = null;
          quoteVolume = null;
        }

        final CandleData _candleData = CandleData(
          closeTime: timestamp,
          openPrice: open,
          highPrice: high,
          lowPrice: low,
          closePrice: close,
          volume: volume,
          quoteVolume: quoteVolume,
        );
        _durationData.add(_candleData);
      }

      data[duration] = _durationData;
      notifyListeners();
    });

    _charts[pair] = ChartData(
      data: data,
      pair: pair,
      chain: chain,
      status: ChartStatus.success,
      updated: DateTime.now().millisecondsSinceEpoch,
    );

    notifyListeners();
  }

  Future<Map<String, dynamic>> _fetchChartData(ChainLink link) async {
    final String pair = '${link.rel}-${link.base}';
    http.Response _res;
    String _body;
    try {
      _res = await http.get('$_chartsUrl/${pair.toLowerCase()}').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log('cex_provider', 'Fetching $pair data timed out');
          throw 'Fetching $pair timed out';
        },
      );
      _body = _res.body;
    } catch (e) {
      Log('cex_provider', 'Failed to fetch data: $e');
      rethrow;
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(_body);
    } catch (e) {
      Log('cex_provider', 'Failed to parse json: $e');
      rethrow;
    }

    return json;
  }

  List<ChainLink> _findChain(String pair) {
    final List<String> abbr = pair.split('-');
    if (abbr[0] == abbr[1]) return null;
    final String base = abbr[1].toLowerCase();
    final String rel = abbr[0].toLowerCase();
    final List<String> tickers = _getTickers();
    List<ChainLink> chain;

    if (tickers == null) return null;

    // try to find simple chain, direct or reverse
    for (String ticker in tickers) {
      final List<String> availableAbbr = ticker.split('-');
      if (!(availableAbbr.contains(rel) && availableAbbr.contains(base))) {
        continue;
      }

      chain = [
        ChainLink(
          rel: availableAbbr[0],
          base: availableAbbr[1],
          reverse: availableAbbr[0] != rel,
        )
      ];
    }

    if (chain != null) return chain;

    tickers.sort((String a, String b) {
      if (a.toLowerCase().contains('btc') && !b.toLowerCase().contains('btc'))
        return -1;
      if (b.toLowerCase().contains('btc') && !a.toLowerCase().contains('btc'))
        return 1;
      return 0;
    });

    OUTER:
    for (String firstLinkStr in tickers) {
      final List<String> firstLinkCoins = firstLinkStr.split('-');
      if (!firstLinkCoins.contains(rel) && !firstLinkCoins.contains(base)) {
        continue;
      }
      final ChainLink firstLink = ChainLink(
        rel: firstLinkCoins[0],
        base: firstLinkCoins[1],
        reverse: firstLinkCoins[1] == rel || firstLinkCoins[1] == base,
      );
      final String secondRel =
          firstLink.reverse ? firstLink.rel : firstLink.base;
      final String secondBase = firstLinkCoins.contains(rel) ? base : rel;

      for (String secondLink in tickers) {
        final List<String> secondLinkCoins = secondLink.split('-');
        if (!(secondLinkCoins.contains(secondRel) &&
            secondLinkCoins.contains(secondBase))) {
          continue;
        }

        chain = [
          firstLink,
          ChainLink(
            rel: secondLinkCoins[0],
            base: secondLinkCoins[1],
            reverse: secondLinkCoins[0] == secondBase ||
                secondLinkCoins[1] == secondRel,
          ),
        ];
        break OUTER;
      }
    }

    if (chain != null) return chain;

    return null;
  }
}

CexPrices cexPrices = CexPrices();

class CexPrices {
  CexPrices() {
    _init();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    activeCurrency = prefs.getInt('activeCurrency') ?? 0;
    _selectedFiat = prefs.getString('selectedFiat') ?? 'USD';
    currencies = [_selectedFiat, 'BTC', 'KMD'];

    Timer.periodic(const Duration(seconds: 60), (_) {
      updatePrices();
      updateRates();
    });
  }

  List<String> currencies;

  int get activeCurrency => _activeCurrency;
  set activeCurrency(int value) {
    _activeCurrency = value;
    prefs?.setInt('activeCurrency', value);
    _notifyListeners();
  }

  String get selectedFiat => _selectedFiat;
  set selectedFiat(String value) {
    if (_isFiat(value)) {
      _selectedFiat = value;
      currencies[0] = value;
      prefs?.setString('selectedFiat', value);
      _notifyListeners();
    }
  }

  List<String> get fiatList => _fiatCurrencies?.keys?.toList();

  SharedPreferences prefs;
  String _selectedFiat;
  int _activeCurrency;
  final Map<String, double> _fiatCurrencies = {};
  final List<CexProvider> _providers = [];
  final Map<String, Map<String, double>> _prices = {};

  Future<void> updateRates() async {
    http.Response _res;
    String _body;
    try {
      _res = await http.get('https://api.openrates.io/latest?base=USD').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw 'Fetching rates prices timed out';
        },
      );
      _body = _res.body;
    } catch (e) {
      Log('cex_provider', 'Failed to fetch rates: $e');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(_body);
    } catch (e) {
      Log('cex_provider', 'Failed to parse rates json: $e');
    }

    if (json == null || json['rates'] == null) {
      if (_fiatCurrencies.isEmpty) _selectedFiat = 'usd';
      return;
    }

    json['rates'].forEach((String fiat, dynamic rate) {
      _fiatCurrencies[fiat] = rate;
    });

    _notifyListeners();
  }

  double getUsdPrice(String abbr) {
    if (abbr == 'USD') return 1;
    if (_isFiat(abbr)) {
      return 1 / _getFiatRate(abbr);
    }

    double price;
    try {
      price = _prices[abbr]['usd'];
    } catch (_) {}

    if (price == null) updatePrices();

    return price;
  }

  String convert(
    double volume, {
    String from,
    String to,
    bool hidden = false,
  }) {
    from ??= 'USD';
    to ??= currencies == null ? null : currencies[_activeCurrency];

    if (from == null || to == null) return '';

    final double fromUsdPrice = getUsdPrice(from);
    final double usdVolume = volume * fromUsdPrice;
    double convertedVolume;
    if (from == to) {
      convertedVolume = volume;
    } else {
      double convertionPrice;
      try {
        convertionPrice = _prices[from][to.toLowerCase()];
      } catch (_) {}
      final double toUsdPrice = getUsdPrice(to);
      if (toUsdPrice != null) {
        convertionPrice ??= fromUsdPrice / toUsdPrice;
        convertedVolume = usdVolume * convertionPrice;
      }
    }

    if (convertedVolume == null || convertedVolume == 0) return '';

    String converted;
    if (_isFiat(to)) {
      converted = convertedVolume.toStringAsFixed(2);
      if (converted == '0.00') converted = formatPrice(convertedVolume, 4);
    } else {
      converted = formatPrice(convertedVolume);
    }

    if (hidden) converted = '**.**';

    if (to == 'USD') return '\$$converted';
    if (to == 'EUR') return '€$converted';
    if (to == 'GBP') return '£$converted';
    return '$converted $to';
  }

  double _getFiatRate(String abbr) {
    return _fiatCurrencies[abbr];
  }

  bool _isFiat(String abbr) {
    if (abbr == 'USD') return true;
    return _fiatCurrencies[abbr] != null;
  }

  Future<void> updatePrices([List<Coin> coinsList]) async {
    coinsList ??= coinsBloc.coinBalance
        ?.map((CoinBalance balance) => balance.coin)
        ?.toList();

    if (coinsList == null) return;

    final List<String> ids =
        coinsList.map((Coin coin) => coin.coingeckoId).toList();

    http.Response _res;
    String _body;
    try {
      _res = await http
          .get('https://api.coingecko.com/api/v3/simple/price?ids=' +
              ids.join(',') +
              '&vs_currencies=usd')
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw 'Fetching usd prices timed out';
        },
      );
      _body = _res.body;
    } catch (e) {
      Log('cex_provider', 'Failed to fetch usd prices: $e');
      rethrow;
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(_body);
    } catch (e) {
      Log('cex_provider', 'Failed to parse prices json: $e');
      rethrow;
    }

    if (json == null) return;

    json.forEach((String coingeckoId, dynamic pricesData) {
      String coinAbbr;
      try {
        coinAbbr = coinsList
            .firstWhere((coin) => coin.coingeckoId == coingeckoId)
            .abbr;
      } catch (_) {}

      if (coinAbbr != null) {
        _prices[coinAbbr] = {};
        pricesData.forEach((String currency, dynamic price) {
          _prices[coinAbbr][currency] = price;
        });
      }
    });

    _notifyListeners();
  }

  void linkProvider(CexProvider provider) {
    _providers.add(provider);
  }

  void unlinkProvider(CexProvider provider) {
    _providers.remove(provider);
  }

  void _notifyListeners() {
    for (CexProvider provider in _providers) provider.notify();
  }
}

class ChainLink {
  ChainLink({
    this.rel,
    this.base,
    this.reverse,
  });
  String rel;
  String base;
  bool reverse;
}

class ChartData {
  ChartData({
    @required this.data,
    this.pair,
    this.chain,
    this.updated,
    this.status,
  });

  Map<String, List<CandleData>> data;
  String pair;
  List<ChainLink> chain;
  int updated; // timestamp, milliseconds
  ChartStatus status;
}

enum ChartStatus {
  success,
  error,
  fetching,
}

class CandleData {
  CandleData({
    @required this.closeTime,
    @required this.openPrice,
    @required this.highPrice,
    @required this.lowPrice,
    @required this.closePrice,
    this.volume,
    this.quoteVolume,
  });

  int closeTime;
  double openPrice;
  double highPrice;
  double lowPrice;
  double closePrice;
  double volume;
  double quoteVolume;
}

List<String> _tickersFallBack = [
  'eth-btc',
  'eth-usdc',
  'btc-usdc',
  'btc-busd',
  'btc-tusd',
  'bat-btc',
  'bat-eth',
  'bat-usdc',
  'bat-tusd',
  'bat-busd',
  'bch-btc',
  'bch-eth',
  'bch-usdc',
  'bch-tusd',
  'bch-busd',
  'dash-btc',
  'dash-eth',
  'dgb-btc',
  'doge-btc',
  'kmd-btc',
  'kmd-eth',
  'ltc-btc',
  'ltc-eth',
  'ltc-usdc',
  'ltc-tusd',
  'ltc-busd',
  'nav-btc',
  'nav-eth',
  'pax-btc',
  'pax-eth',
  'qtum-btc',
  'qtum-eth',
  'rvn-btc',
  'xzc-btc',
  'xzc-eth',
  'zec-btc',
  'zec-eth',
  'zec-usdc',
  'zec-tusd',
  'zec-busd'
];
