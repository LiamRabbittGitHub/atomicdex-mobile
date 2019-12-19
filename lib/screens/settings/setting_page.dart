import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:komodo_dex/blocs/authenticate_bloc.dart';
import 'package:komodo_dex/blocs/dialog_bloc.dart';
import 'package:komodo_dex/blocs/main_bloc.dart';
import 'package:komodo_dex/blocs/settings_bloc.dart';
import 'package:komodo_dex/blocs/wallet_bloc.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/model/base_service.dart';
import 'package:komodo_dex/model/get_recent_swap.dart';
import 'package:komodo_dex/model/recent_swaps.dart';
import 'package:komodo_dex/model/result.dart';
import 'package:komodo_dex/screens/authentification/dislaimer_page.dart';
import 'package:komodo_dex/screens/authentification/lock_screen.dart';
import 'package:komodo_dex/screens/authentification/pin_page.dart';
import 'package:komodo_dex/screens/authentification/unlock_wallet_page.dart';
import 'package:komodo_dex/screens/settings/select_language_page.dart';
import 'package:komodo_dex/screens/settings/view_seed_unlock_page.dart';
import 'package:komodo_dex/services/api_providers.dart';
import 'package:komodo_dex/services/market_maker_service.dart';
import 'package:komodo_dex/utils/log.dart';
import 'package:komodo_dex/utils/utils.dart';
import 'package:komodo_dex/widgets/primary_button.dart';
import 'package:komodo_dex/widgets/secondary_button.dart';
import 'package:komodo_dex/widgets/shared_preferences_builder.dart';
import 'package:komodo_dex/widgets/sound_volume_button.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info/package_info.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String version = '';

  @override
  void initState() {
    _getVersionApplication().then((String onValue) {
      setState(() {
        version = onValue;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    mainBloc.isUrlLaucherIsOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final Locale myLocale = Localizations.localeOf(context);
    // Log.println('setting_page:62', 'current locale: $myLocale');
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).settings.toUpperCase(),
          key: const Key('settings-title'),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
            canvasColor: Theme.of(context).primaryColor,
            textTheme: Theme.of(context).textTheme),
        child: Container(
          child: ListView(
            children: <Widget>[
              _buildTitle(AppLocalizations.of(context).logoutsettings),
              _buildLogout(),
              const SizedBox(
                height: 1,
              ),
              _buildLogOutOnExit(),
              _buildTitle(AppLocalizations.of(context).settingLanguageTitle),
              _buildLanguages(),
              _buildTitle(AppLocalizations.of(context).soundTitle),
              _buildSound(),
              _buildTitle(AppLocalizations.of(context).security),
              _buildActivatePIN(),
              const SizedBox(
                height: 1,
              ),
              _buildActivateBiometric(),
              const SizedBox(
                height: 1,
              ),
              _buildChangePIN(),
              const SizedBox(
                height: 1,
              ),
              _buildSendFeedback(),
              walletBloc.currentWallet != null
                  ? _buildTitle(AppLocalizations.of(context).backupTitle)
                  : Container(),
              walletBloc.currentWallet != null ? _buildViewSeed() : Container(),
              const SizedBox(
                height: 1,
              ),
              _buildTitle(AppLocalizations.of(context).legalTitle),
              _buildDisclaimerToS(),
              walletBloc.currentWallet != null
                  ? _buildTitle(version)
                  : Container(),
              const SizedBox(
                height: 48,
              ),
              walletBloc.currentWallet != null
                  ? _buildDeleteWallet()
                  : Container(),
              const SizedBox(
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getVersionApplication() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version =
        AppLocalizations.of(context).version + ' : ' + packageInfo.version;

    try {
      final dynamic versionmm2 = await ApiProvider().getVersionMM2(
          MarketMakerService().client, BaseService(method: 'version'));
      if (versionmm2 is ResultSuccess && versionmm2 != null) {
        version += ' - ${versionmm2.result}';
      }
    } catch (e) {
      Log.println('setting_page:145', e);
      rethrow;
    }
    return version;
  }

  Widget _buildLanguages() {
    return CustomTile(
      onPressed: () {
        Navigator.push<dynamic>(
            context,
            MaterialPageRoute<dynamic>(
                builder: (BuildContext context) => SelectLanguagePage(
                      currentLoc: Localizations.localeOf(context),
                    )));
      },
      child: SharedPreferencesBuilder<dynamic>(
          pref: 'current_languages',
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            return ListTile(
              trailing: Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.7)),
              title: Text(
                snapshot.hasData
                    ? settingsBloc.getNameLanguage(context, snapshot.data)
                    : '',
                style: Theme.of(context).textTheme.body1.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.7)),
              ),
            );
          }),
    );
  }

  Widget _buildSound() {
    return Column(
      children: [
        CustomTile(
          child: ListTile(
            title: Text(
              AppLocalizations.of(context).soundOption,
              style: Theme.of(context).textTheme.body1.copyWith(
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withOpacity(0.7)),
            ),
            trailing:
                const SoundVolumeButton(key: Key('settings-sound-button')),
          ),
        ),
        const SizedBox(
          height: 1,
        ),
        SoundPicker(AppLocalizations.of(context).soundTaker,
            AppLocalizations.of(context).soundTakerDesc),
        const SizedBox(
          height: 1,
        ),
        SoundPicker(AppLocalizations.of(context).soundMaker,
            AppLocalizations.of(context).soundMakerDesc),
        const SizedBox(
          height: 1,
        ),
        SoundPicker(AppLocalizations.of(context).soundActive,
            AppLocalizations.of(context).soundActiveDesc),
        const SizedBox(
          height: 1,
        ),
        SoundPicker(AppLocalizations.of(context).soundFailed,
            AppLocalizations.of(context).soundFailedDesc),
        const SizedBox(
          height: 1,
        ),
        SoundPicker(AppLocalizations.of(context).soundApplause,
            AppLocalizations.of(context).soundApplauseDesc),
      ],
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.body2,
      ),
    );
  }

  Widget _buildActivatePIN() {
    return CustomTile(
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                AppLocalizations.of(context).activateAccessPin,
                style: Theme.of(context).textTheme.body1.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.7)),
              ),
            ),
            SharedPreferencesBuilder<dynamic>(
              pref: 'switch_pin',
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                return snapshot.hasData
                    ? Switch(
                        value: snapshot.data,
                        onChanged: (bool dataSwitch) {
                          Log.println('setting_page:255',
                              'dataSwitch' + dataSwitch.toString());
                          setState(() {
                            if (snapshot.data) {
                              Navigator.push<dynamic>(
                                  context,
                                  MaterialPageRoute<dynamic>(
                                      builder: (BuildContext context) =>
                                          LockScreen(
                                            context: context,
                                            pinStatus: PinStatus.DISABLED_PIN,
                                          )));
                            } else {
                              SharedPreferences.getInstance()
                                  .then((SharedPreferences data) {
                                data.setBool('switch_pin', dataSwitch);
                              });
                            }
                          });
                        })
                    : Container();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActivateBiometric() {
    return FutureBuilder<bool>(
        initialData: false,
        future: checkBiometrics(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData && snapshot.data) {
            return CustomTile(
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).activateAccessBiometric,
                        style: Theme.of(context).textTheme.body1.copyWith(
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    SharedPreferencesBuilder<dynamic>(
                      pref: 'switch_pin_biometric',
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapshot) {
                        return snapshot.hasData
                            ? Switch(
                                value: snapshot.data,
                                onChanged: (bool dataSwitch) {
                                  setState(() {
                                    if (snapshot.data) {
                                      authenticateBiometrics(context,
                                              PinStatus.DISABLED_PIN_BIOMETRIC)
                                          .then((bool onValue) {
                                        if (onValue) {
                                          setState(() {
                                            SharedPreferences.getInstance()
                                                .then((SharedPreferences data) {
                                              data.setBool(
                                                  'switch_pin_biometric',
                                                  false);
                                            });
                                          });
                                        }
                                      });
                                    } else {
                                      SharedPreferences.getInstance()
                                          .then((SharedPreferences data) {
                                        data.setBool(
                                            'switch_pin_biometric', dataSwitch);
                                      });
                                    }
                                  });
                                })
                            : Container();
                      },
                    )
                  ],
                ),
              ),
            );
          } else {
            return Container();
          }
        });
  }

  Widget _buildChangePIN() {
    return CustomTile(
      onPressed: () => Navigator.push<dynamic>(
          context,
          MaterialPageRoute<dynamic>(
              builder: (BuildContext context) => UnlockWalletPage(
                    textButton: AppLocalizations.of(context).unlock,
                    wallet: walletBloc.currentWallet,
                    isSignWithSeedIsEnabled: false,
                    onSuccess: (_, String password) {
                      Navigator.push<dynamic>(
                          context,
                          MaterialPageRoute<dynamic>(
                              builder: (BuildContext context) => PinPage(
                                  title:
                                      AppLocalizations.of(context).lockScreen,
                                  subTitle: AppLocalizations.of(context)
                                      .enterOldPinCode,
                                  pinStatus: PinStatus.CHANGE_PIN,
                                  password: password)));
                    },
                  ))),
      child: ListTile(
        trailing:
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
        title: Text(
          AppLocalizations.of(context).changePin,
          style: Theme.of(context).textTheme.body1.copyWith(
              fontWeight: FontWeight.w300,
              color: Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildSendFeedback() {
    return CustomTile(
      onPressed: () => _shareFileDialog(),
      child: ListTile(
        key: const Key('setting-title-feedback'),
        trailing:
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
        title: Text(
          AppLocalizations.of(context).feedback,
          style: Theme.of(context).textTheme.body1.copyWith(
              fontWeight: FontWeight.w300,
              color: Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildViewSeed() {
    return CustomTile(
      onPressed: () {
        Navigator.push<dynamic>(
            context,
            MaterialPageRoute<dynamic>(
                builder: (BuildContext context) => ViewSeedUnlockPage()));
      },
      child: ListTile(
        trailing:
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
        title: Text(
          AppLocalizations.of(context).viewSeed,
          style: Theme.of(context).textTheme.body1.copyWith(
              fontWeight: FontWeight.w300,
              color: Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildDisclaimerToS() {
    return CustomTile(
        child: ListTile(
          trailing:
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
          title: Text(
            AppLocalizations.of(context).disclaimerAndTos,
            style: Theme.of(context).textTheme.body1.copyWith(
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7)),
          ),
        ),
        onPressed: () {
          Navigator.push<dynamic>(
            context,
            MaterialPageRoute<dynamic>(
                builder: (BuildContext context) => const DislaimerPage(
                      readOnly: true,
                    )),
          );
        });
  }

  Widget _buildLogout() {
    return CustomTile(
      onPressed: () {
        Log.println('setting_page:448', 'PRESSED');
        authBloc.logout().then((_) {
          Log.println('setting_page:450', 'PRESSED');
          SystemChannels.platform.invokeMethod<dynamic>('SystemNavigator.pop');
        });
      },
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: SvgPicture.asset('assets/logout_setting.svg'),
        ),
        title: Text(AppLocalizations.of(context).logout,
            style: Theme.of(context).textTheme.body1.copyWith(
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7))),
      ),
    );
  }

  Widget _buildLogOutOnExit() {
    return CustomTile(
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                AppLocalizations.of(context).logoutOnExit,
                style: Theme.of(context).textTheme.body1.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.7)),
              ),
            ),
            SharedPreferencesBuilder<dynamic>(
              pref: 'switch_pin_log_out_on_exit',
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                return snapshot.hasData
                    ? Switch(
                        value: snapshot.data,
                        onChanged: (bool dataSwitch) {
                          setState(() {
                            SharedPreferences.getInstance()
                                .then((SharedPreferences data) {
                              data.setBool(
                                  'switch_pin_log_out_on_exit', dataSwitch);
                            });
                          });
                        })
                    : Container();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteWallet() {
    return CustomTile(
      onPressed: () => _showDialogDeleteWallet(),
      backgroundColor: Theme.of(context).errorColor.withOpacity(0.8),
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: SvgPicture.asset('assets/delete_setting.svg'),
        ),
        title: Text(AppLocalizations.of(context).deleteWallet,
            style: Theme.of(context).textTheme.body1.copyWith(
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7))),
      ),
    );
  }

  void _showDialogDeleteWallet() {
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
          builder: (BuildContext context) => UnlockWalletPage(
                textButton: AppLocalizations.of(context).unlock,
                wallet: walletBloc.currentWallet,
                isSignWithSeedIsEnabled: false,
                onSuccess: (_, String password) {
                  Navigator.of(context).pop();
                  dialogBloc.dialog = showDialog<dynamic>(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          backgroundColor: Colors.white,
                          title: Column(
                            children: <Widget>[
                              SvgPicture.asset('assets/delete_wallet.svg'),
                              const SizedBox(
                                height: 16,
                              ),
                              Text(
                                AppLocalizations.of(context)
                                    .deleteWallet
                                    .toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .title
                                    .copyWith(
                                        color: Theme.of(context).errorColor),
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                            ],
                          ),
                          children: <Widget>[
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(children: <InlineSpan>[
                                TextSpan(
                                    text: AppLocalizations.of(context)
                                        .settingDialogSpan1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .body1
                                        .copyWith(
                                            color: Theme.of(context)
                                                .primaryColor)),
                                TextSpan(
                                    text: walletBloc.currentWallet.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .body1
                                        .copyWith(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold)),
                                TextSpan(
                                    text: AppLocalizations.of(context)
                                        .settingDialogSpan2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .body1
                                        .copyWith(
                                            color: Theme.of(context)
                                                .primaryColor)),
                              ]),
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(children: <InlineSpan>[
                                  TextSpan(
                                      text: AppLocalizations.of(context)
                                          .settingDialogSpan3,
                                      style: Theme.of(context)
                                          .textTheme
                                          .body1
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .primaryColor)),
                                  TextSpan(
                                      text: AppLocalizations.of(context)
                                          .settingDialogSpan4,
                                      style: Theme.of(context)
                                          .textTheme
                                          .body1
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text: AppLocalizations.of(context)
                                          .settingDialogSpan5,
                                      style: Theme.of(context)
                                          .textTheme
                                          .body1
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .primaryColor)),
                                ]),
                              ),
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: SecondaryButton(
                                    text: AppLocalizations.of(context).cancel,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    isDarkMode: false,
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child: PrimaryButton(
                                    text: AppLocalizations.of(context).delete,
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      settingsBloc.setDeleteLoading(true);
                                      _showLoadingDelete();
                                      await walletBloc.deleteSeedPhrase(
                                          password, walletBloc.currentWallet);
                                      await walletBloc.deleteCurrentWallet();
                                      settingsBloc.setDeleteLoading(false);
                                    },
                                    backgroundColor:
                                        Theme.of(context).errorColor,
                                    isDarkMode: false,
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                          ],
                        );
                      }).then((dynamic _) {
                    dialogBloc.dialog = null;
                  });
                },
              )),
    );
  }

  void _showLoadingDelete() {
    dialogBloc.dialog = showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ShowLoadingDelete();
        }).then((dynamic _) {
      dialogBloc.dialog = null;
    });
  }

  Future<void> _shareFile() async {
    Navigator.of(context).pop();
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String os = Platform.isAndroid ? 'Android' : 'iOS';
    final dynamic recentSwap = await ApiProvider().getRecentSwaps(
        MarketMakerService().client, GetRecentSwap(limit: 100, fromUuid: null));

    if (recentSwap is RecentSwaps) {
      if (MarketMakerService().sink != null) {
        MarketMakerService().sink.write('\n\nMy recent swaps: \n\n');
        MarketMakerService().sink.write(recentSwapsToJson(recentSwap) + '\n\n');
        MarketMakerService()
            .sink
            .write('AtomicDEX mobile ${packageInfo.version} $os\n');
      }
    }
    mainBloc.isUrlLaucherIsOpen = true;
    Share.shareFile(File('${MarketMakerService().filesPath}log.txt'),
        subject: 'My logs for the ${DateTime.now().toIso8601String()}');
  }

  Future<void> _shareFileDialog() async {
    dialogBloc.dialog = showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context).feedback),
            content: Text(AppLocalizations.of(context).warningShareLogs),
            actions: <Widget>[
              FlatButton(
                child: Text(AppLocalizations.of(context).cancel),
                onPressed: () => Navigator.of(context).pop(),
              ),
              RaisedButton(
                key: const Key('setting-share-button'),
                child: Text(AppLocalizations.of(context).share),
                onPressed: () => _shareFile(),
              )
            ],
          );
        }).then((dynamic _) {
      dialogBloc.dialog = null;
    });
  }
}

/// See if the file is an auudio file we can play.
bool checkAudioFile(String path) {
  if (path == null) return false;
  return path.endsWith('.mp3') || path.endsWith('.wav');
}

class FilePickerButton extends StatelessWidget {
  const FilePickerButton(this.description);
  final String description;
  @override
  Widget build(BuildContext context) {
    return IconButton(
        key: const Key('file-picker-button'),
        icon: Icon(Icons.folder_open),
        color: Theme.of(context).toggleableActiveColor,
        onPressed: () async {
          // TODO: File picker currently triggers the PIN screen...
          final String path = await FilePicker.getFilePath();

          // on iOS this happens *after* pin lock, but very close in time to it (same second),
          // on Android/debug *before* pin lock,
          // chance is it's unordered.
          Log.println('setting_page:761', 'file picked: $path');

          final bool ck = checkAudioFile(path);
          if (!ck) {
            showDialog<dynamic>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context).soundCantPlayThat),
                content: Text(AppLocalizations.of(context)
                    .soundCantPlayThatMsg(description)),
                actions: <Widget>[
                  FlatButton(
                    child: const Text('Ok'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          }
          Log.println('setting_page:782','path: $path');
        });
  }
}

class SoundPicker extends StatelessWidget {
  const SoundPicker(this.name, this.description);
  final String name, description;
  @override
  Widget build(BuildContext context) {
    return CustomTile(
        child: Tooltip(
            message: AppLocalizations.of(context).soundPlayedWhen(description),
            child: ListTile(
              title: Text(
                name,
                style: Theme.of(context).textTheme.body1.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.7)),
              ),
              trailing: FilePickerButton(description),
            )));
  }
}

class CustomTile extends StatefulWidget {
  const CustomTile({Key key, this.onPressed, this.backgroundColor, this.child})
      : super(key: key);

  final Widget child;
  final Function onPressed;
  final Color backgroundColor;

  @override
  _CustomTileState createState() => _CustomTileState();
}

class _CustomTileState extends State<CustomTile> {
  Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (widget.backgroundColor == null) {
      backgroundColor = Theme.of(context).primaryColor;
    } else {
      backgroundColor = widget.backgroundColor;
    }
    return Container(
      color: backgroundColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

class ShowLoadingDelete extends StatefulWidget {
  @override
  _ShowLoadingDeleteState createState() => _ShowLoadingDeleteState();
}

class _ShowLoadingDeleteState extends State<ShowLoadingDelete> {
  @override
  void initState() {
    super.initState();
    settingsBloc.outIsDeleteLoading.listen((bool onData) {
      if (!onData) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: <Widget>[
        Center(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const <Widget>[
            CircularProgressIndicator(),
            SizedBox(
              width: 16,
            ),
            Text('Deleting wallet...')
          ],
        ))
      ],
    );
  }
}
