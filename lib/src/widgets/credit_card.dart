import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:moyasar/moyasar.dart';
import 'package:moyasar/src/models/ui/credit_button_style.dart';
import 'package:moyasar/src/moyasar.dart';

import 'package:moyasar/src/models/card_form_model.dart';
import 'package:moyasar/src/models/payment_request.dart';
import 'package:moyasar/src/models/sources/card/card_request_source.dart';

import 'package:moyasar/src/utils/card_utils.dart';
import 'package:moyasar/src/utils/input_formatters.dart';
import 'package:moyasar/src/widgets/network_icons.dart';
import 'package:moyasar/src/widgets/three_d_s_webview.dart';

import 'credit_button/credit_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quickyclean/features/bookings/presentation/cubit/slots_bloc/slots_bloc.dart';
import 'package:quickyclean/features/bookings/presentation/cubit/bookings_cubit.dart';
import 'package:quickyclean/features/map/presentation/cubit/addresses/addresses_cubit.dart';
import 'package:quickyclean/core/packages/quicky_toast.dart';
import 'package:quickyclean/core/utils/app_assets.dart';
import 'package:quickyclean/core/utils/app_extensions.dart';
import 'package:quickyclean/core/utils/app_strings.dart';

typedef ButtonBuilderCallBack = Widget Function(
  BuildContext context,
  String payAmount,
  bool isLoading,
  VoidCallback onPressed,
);

/// The widget that shows the Credit Card form and manages the 3DS step.
class CreditCard extends StatefulWidget {
  const CreditCard({
    super.key,
    required this.config,
    required this.onPaymentResult,
    this.locale = const Localization.en(),
    this.creditButtonStyle,
    this.expiryLabelWidget,
    this.cvcLabelWidget,
    this.nameOnCardDecoration,
    this.cardNumberDecoration,
    this.expiryDecoration,
    this.cvcDecoration,
    this.creditBuilder,
  });

  final Function onPaymentResult;
  final PaymentConfig config;
  final Localization locale;
  final CreditButtonStyle? creditButtonStyle;
  final Widget? expiryLabelWidget;
  final Widget? cvcLabelWidget;
  final InputDecoration? nameOnCardDecoration;
  final InputDecoration? cardNumberDecoration;
  final InputDecoration? expiryDecoration;
  final InputDecoration? cvcDecoration;
  final ButtonBuilderCallBack? creditBuilder;

  @override
  State<CreditCard> createState() => _CreditCardState();
}

class _CreditCardState extends State<CreditCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _cardData = CardFormModel();

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  bool _isSubmitting = false;

  bool _tokenizeCard = false;

  bool _manualPayment = false;

  late final BookingsCubit bookingCubit;
  late final AddressesCubit _addressesCubit;

  late final SlotsBloc slotsBloc;

  @override
  void initState() {
    bookingCubit = BookingsCubit.of(context);
    _addressesCubit = AddressesCubit.of(context);
    slotsBloc = SlotsBloc.of(context);
    super.initState();
    setState(() {
      _tokenizeCard = widget.config.creditCard?.saveCard ?? false;
      _manualPayment = widget.config.creditCard?.manual ?? false;
    });
  }

  void _saveForm() async {
    closeKeyboard();

    bool isValidForm =
        _formKey.currentState != null && _formKey.currentState!.validate();

    if (!isValidForm) {
      setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    _formKey.currentState?.save();

    if (widget.config.description == "Buy a package and make order") {
      slotsBloc.add(SlotsFetch(
        date: bookingCubit.selectedBookingDate,
        latitude: _addressesCubit.userFavoriteAddress?.latitude,
        longitude: _addressesCubit.userFavoriteAddress?.longitude,
      ));

      await slotsBloc.stream
          .firstWhere((state) => state is SlotsLoaded || state is SlotsError);

      try {
        var x = slotsBloc.slots
            .firstWhere((element) =>
                element.id == bookingCubit.selectedSlot?.id &&
                element.isActive == true)
            .isNotNull;
        // print("**************");
        // print(x);
        // print("**************");
        if (x == true) {
          final source = CardPaymentRequestSource(
            creditCardData: _cardData,
            tokenizeCard: _tokenizeCard,
            manualPayment: _manualPayment,
          );
          final paymentRequest = PaymentRequest(widget.config, source);

          setState(() => _isSubmitting = true);

          final result = await Moyasar.pay(
              apiKey: widget.config.publishableApiKey,
              paymentRequest: paymentRequest);

          setState(() => _isSubmitting = false);

          if (result is! PaymentResponse ||
              result.status != PaymentStatus.initiated) {
            widget.onPaymentResult(result);
            return;
          }

          final String transactionUrl =
              (result.source as CardPaymentResponseSource).transactionUrl;

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                maintainState: false,
                builder: (context) => ThreeDSWebView(
                  transactionUrl: transactionUrl,
                  on3dsDone: (String status, String message) async {
                    if (status == PaymentStatus.paid.name) {
                      result.status = PaymentStatus.paid;
                    } else if (status == PaymentStatus.authorized.name) {
                      result.status = PaymentStatus.authorized;
                    } else {
                      result.status = PaymentStatus.failed;
                      (result.source as CardPaymentResponseSource).message =
                          message;
                    }
                    Navigator.pop(context);
                    widget.onPaymentResult(result);
                  },
                ),
              ),
            );
          }
        } else {
          DefaultToast.show(
            icon: AppIcons.alarm,
            title: AppStrings.unavailableSlot.trans(),
            subtitle: AppStrings.timeOutSlot.trans(),
          );
        }
      } catch (e) {
        DefaultToast.show(
          icon: AppIcons.alarm,
          title: AppStrings.unavailableSlot.trans(),
          subtitle: AppStrings.timeOutSlot.trans(),
        );
      }
    } else {
      final source = CardPaymentRequestSource(
        creditCardData: _cardData,
        tokenizeCard: _tokenizeCard,
        manualPayment: _manualPayment,
      );
      final paymentRequest = PaymentRequest(widget.config, source);

      setState(() => _isSubmitting = true);

      final result = await Moyasar.pay(
          apiKey: widget.config.publishableApiKey,
          paymentRequest: paymentRequest);

      setState(() => _isSubmitting = false);

      if (result is! PaymentResponse ||
          result.status != PaymentStatus.initiated) {
        widget.onPaymentResult(result);
        return;
      }

      final String transactionUrl =
          (result.source as CardPaymentResponseSource).transactionUrl;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            maintainState: false,
            builder: (context) => ThreeDSWebView(
              transactionUrl: transactionUrl,
              on3dsDone: (String status, String message) async {
                if (status == PaymentStatus.paid.name) {
                  result.status = PaymentStatus.paid;
                } else if (status == PaymentStatus.authorized.name) {
                  result.status = PaymentStatus.authorized;
                } else {
                  result.status = PaymentStatus.failed;
                  (result.source as CardPaymentResponseSource).message =
                      message;
                }
                Navigator.pop(context);
                widget.onPaymentResult(result);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      autovalidateMode: _autoValidateMode,
      key: _formKey,
      child: Column(
        children: [
          CardFormField(
            inputDecoration: widget.nameOnCardDecoration ??
                _buildInputDecoration(
                  hintText: widget.locale.nameOnCard,
                ),
            keyboardType: TextInputType.text,
            validator: (String? input) =>
                CardUtils.validateName(input, widget.locale),
            onSaved: (value) => _cardData.name = value ?? '',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z. ]')),
            ],
          ),
          CardFormField(
            inputDecoration: widget.cardNumberDecoration ??
                _buildInputDecoration(
                  hintText: widget.locale.cardNumber,
                  addNetworkIcons: true,
                ),
            validator: (String? input) =>
                CardUtils.validateCardNum(input, widget.locale),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              CardNumberInputFormatter(),
            ],
            onSaved: (value) =>
                _cardData.number = CardUtils.getCleanedNumber(value!),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.expiryLabelWidget != null)
                      widget.expiryLabelWidget!,
                    CardFormField(
                      inputDecoration: widget.expiryDecoration ??
                          _buildInputDecoration(
                            hintText: '${widget.locale.expiry} (MM / YY)',
                          ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        CardMonthInputFormatter(),
                      ],
                      validator: (String? input) =>
                          CardUtils.validateDate(input, widget.locale),
                      onSaved: (value) {
                        List<String> expireDate =
                            CardUtils.getExpiryDate(value!);
                        _cardData.month = expireDate.first;
                        _cardData.year = expireDate[1];
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 16.0,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.cvcLabelWidget != null) widget.cvcLabelWidget!,
                    CardFormField(
                      inputDecoration: widget.cvcDecoration ??
                          _buildInputDecoration(
                            hintText: widget.locale.cvc,
                          ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (String? input) =>
                          CardUtils.validateCVC(input, widget.locale),
                      onSaved: (value) => _cardData.cvc = value ?? '',
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: widget.creditBuilder != null
                ? widget.creditBuilder!(
                    context,
                    _showAmount(widget.config.amount, widget.locale),
                    _isSubmitting,
                    _saveForm)
                : SizedBox(
                    child: CreditCardButton(
                      buttonStyle: widget.creditButtonStyle,
                      onPressed: _isSubmitting ? () {} : _saveForm,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : Text(
                              _showAmount(widget.config.amount, widget.locale),
                              style: widget.creditButtonStyle?.textStyle,
                            ),
                    ),
                  ),
          ),
          SaveCardNotice(tokenizeCard: _tokenizeCard, locale: widget.locale)
        ],
      ),
    );
  }

  String _showAmount(int amount, Localization locale) {
    final formattedAmount = (amount / 100).toStringAsFixed(2);

    if (locale.languageCode == 'en') {
      return '${locale.pay} $formattedAmount SAR';
    }

    return '${locale.pay} $formattedAmount ر.س';
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    bool addNetworkIcons = false,
  }) {
    return InputDecoration(
      suffixIcon: addNetworkIcons ? const NetworkIcons() : null,
      hintText: hintText,
      focusedErrorBorder: defaultErrorBorder,
      enabledBorder: defaultEnabledBorder,
      focusedBorder: defaultFocusedBorder,
      errorBorder: defaultErrorBorder,
      contentPadding: const EdgeInsets.all(8.0),
    );
  }
}

class SaveCardNotice extends StatelessWidget {
  const SaveCardNotice({
    super.key,
    required this.tokenizeCard,
    required this.locale,
  });

  final bool tokenizeCard;
  final Localization locale;

  @override
  Widget build(BuildContext context) {
    return tokenizeCard
        ? Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.info,
                  color: blueColor,
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                ),
                Text(
                  locale.saveCardNotice,
                  style: TextStyle(color: blueColor),
                ),
              ],
            ))
        : const SizedBox.shrink();
  }
}

class CardFormField extends StatelessWidget {
  final void Function(String?)? onSaved;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final InputDecoration? inputDecoration;

  const CardFormField({
    Key? key,
    required this.onSaved,
    this.validator,
    this.inputDecoration,
    this.keyboardType = TextInputType.number,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        decoration: inputDecoration,
        validator: validator,
        onSaved: onSaved,
        inputFormatters: inputFormatters,
      ),
    );
  }
}

void closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

BorderRadius defaultBorderRadius = const BorderRadius.all(Radius.circular(8));

OutlineInputBorder defaultEnabledBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.grey[400]!),
    borderRadius: defaultBorderRadius);

OutlineInputBorder defaultFocusedBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.grey[600]!),
    borderRadius: defaultBorderRadius);

OutlineInputBorder defaultErrorBorder = OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.red),
    borderRadius: defaultBorderRadius);

Color blueColor = Colors.blue[700]!;
