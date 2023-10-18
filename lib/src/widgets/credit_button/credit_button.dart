import 'package:flutter/material.dart';
import 'package:moyasar/src/models/ui/credit_button_style.dart';

class CreditCardButton extends StatelessWidget {
  const CreditCardButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.buttonStyle,
  });
  final VoidCallback onPressed;
  final Widget child;
  final CreditButtonStyle? buttonStyle;

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      fillColor:
          buttonStyle?.fillColor ?? Theme.of(context).colorScheme.primary,
      constraints: buttonStyle?.constraints ??
          const BoxConstraints(
            minWidth: double.infinity,
            minHeight: 56,
          ),
      elevation: 0.0,
      onPressed: onPressed,
      //textStyle: buttonStyle?.textStyle,
      shape: buttonStyle?.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              12.0,
            ),
          ),
      child: child,
      // child: isSubmitting
      //     ? const CircularProgressIndicator(
      //         color: Colors.white,
      //         strokeWidth: 2,
      //       )
      //     : Text(
      //         text,
      //         style: buttonStyle?.textStyle ??
      //             const TextStyle(
      //               color: Colors.white,
      //               fontWeight: FontWeight.w600,
      //             ),
      //       ),
    );
  }
}
