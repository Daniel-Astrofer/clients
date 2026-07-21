#!/bin/bash
set -e

cd lib/features/movement

mkdir -p presentation/hub
mkdir -p presentation/send
mkdir -p presentation/receive
mkdir -p presentation/activity
mkdir -p presentation/shared
mkdir -p data/entities
mkdir -p data/repositories
mkdir -p kernel/intent
mkdir -p kernel/routing

# Hub
mv screens/movement_hub_screen.dart presentation/hub/

# Send
mv screens/send_*.dart presentation/send/
mv widgets/send_money_components.dart presentation/send/ || true
mv widgets/withdraw_amount_step.dart presentation/send/ || true
mv widgets/withdraw_components.dart presentation/send/ || true
mv widgets/destination_capture_sheet.dart presentation/send/ || true
mv flow/send_money_flow_notifier.dart presentation/send/ || true

# Receive
mv screens/receive_*.dart presentation/receive/
mv widgets/receive_flow_ui.dart presentation/receive/ || true
mv flow/receive_nfc_availability_provider.dart presentation/receive/ || true

# Activity
mv screens/statement_screen.dart presentation/activity/ || true
mv screens/transaction_detail_screen.dart presentation/activity/ || true
mv widgets/transaction_*.dart presentation/activity/ || true
mv widgets/statement_*.dart presentation/activity/ || true
mv widgets/recent_transactions_list.dart presentation/activity/ || true
mv widgets/activity_glyph.dart presentation/activity/ || true
mv widgets/expense_categories_list.dart presentation/activity/ || true
mv widgets/financial_activity_details_sheet.dart presentation/activity/ || true
mv widgets/home_activity_surface.dart presentation/activity/ || true
mv widgets/wallet_transaction_list.dart presentation/activity/ || true
mv domain/transaction_presentation.dart presentation/activity/ || true
mv domain/transaction_taxonomy.dart presentation/activity/ || true
mv domain/transaction_filter_engine.dart presentation/activity/ || true

# Shared
mv screens/movement_amount_screen.dart presentation/shared/ || true
mv widgets/amount_input_pad.dart presentation/shared/ || true
mv widgets/financial_status_badge.dart presentation/shared/ || true
mv widgets/internal_recent_avatar.dart presentation/shared/ || true
mv widgets/lightning_keypad.dart presentation/shared/ || true
mv widgets/lightning_top_bar.dart presentation/shared/ || true
mv widgets/movement_confirmation_surface.dart presentation/shared/ || true
mv widgets/quick_contact_list.dart presentation/shared/ || true

# Flow / Routing
mv flow/movement_flow_coordinator.dart kernel/routing/ || true
mv flow/kfe_receiving_capabilities_service.dart data/ || true

# Domain
mv domain/entities/* data/entities/ || true
mv domain/repositories/* data/repositories/ || true
mv domain/services/* data/ || true
mv domain/usecases/* data/ || true
mv domain/payment_intent* kernel/intent/ || true
mv domain/* data/ 2>/dev/null || true

# Utils -> Shared or Data
mv utils/* data/ 2>/dev/null || true

# Remove old dirs
rm -rf screens widgets flow domain utils || true

# Update imports globally in lib and test
cd ../../../
find lib test -type f -name "*.dart" -print0 | xargs -0 sed -i \
  -e 's|features/movement/screens/movement_hub_screen.dart|features/movement/presentation/hub/movement_hub_screen.dart|g' \
  -e 's|features/movement/screens/send_|features/movement/presentation/send/send_|g' \
  -e 's|features/movement/widgets/send_money_components.dart|features/movement/presentation/send/send_money_components.dart|g' \
  -e 's|features/movement/widgets/withdraw_amount_step.dart|features/movement/presentation/send/withdraw_amount_step.dart|g' \
  -e 's|features/movement/widgets/withdraw_components.dart|features/movement/presentation/send/withdraw_components.dart|g' \
  -e 's|features/movement/widgets/destination_capture_sheet.dart|features/movement/presentation/send/destination_capture_sheet.dart|g' \
  -e 's|features/movement/flow/send_money_flow_notifier.dart|features/movement/presentation/send/send_money_flow_notifier.dart|g' \
  -e 's|features/movement/screens/receive_|features/movement/presentation/receive/receive_|g' \
  -e 's|features/movement/widgets/receive_flow_ui.dart|features/movement/presentation/receive/receive_flow_ui.dart|g' \
  -e 's|features/movement/flow/receive_nfc_availability_provider.dart|features/movement/presentation/receive/receive_nfc_availability_provider.dart|g' \
  -e 's|features/movement/screens/statement_screen.dart|features/movement/presentation/activity/statement_screen.dart|g' \
  -e 's|features/movement/screens/transaction_detail_screen.dart|features/movement/presentation/activity/transaction_detail_screen.dart|g' \
  -e 's|features/movement/widgets/transaction_|features/movement/presentation/activity/transaction_|g' \
  -e 's|features/movement/widgets/statement_|features/movement/presentation/activity/statement_|g' \
  -e 's|features/movement/widgets/recent_transactions_list.dart|features/movement/presentation/activity/recent_transactions_list.dart|g' \
  -e 's|features/movement/widgets/activity_glyph.dart|features/movement/presentation/activity/activity_glyph.dart|g' \
  -e 's|features/movement/widgets/expense_categories_list.dart|features/movement/presentation/activity/expense_categories_list.dart|g' \
  -e 's|features/movement/widgets/financial_activity_details_sheet.dart|features/movement/presentation/activity/financial_activity_details_sheet.dart|g' \
  -e 's|features/movement/widgets/home_activity_surface.dart|features/movement/presentation/activity/home_activity_surface.dart|g' \
  -e 's|features/movement/widgets/wallet_transaction_list.dart|features/movement/presentation/activity/wallet_transaction_list.dart|g' \
  -e 's|features/movement/domain/transaction_presentation.dart|features/movement/presentation/activity/transaction_presentation.dart|g' \
  -e 's|features/movement/domain/transaction_taxonomy.dart|features/movement/presentation/activity/transaction_taxonomy.dart|g' \
  -e 's|features/movement/domain/transaction_filter_engine.dart|features/movement/presentation/activity/transaction_filter_engine.dart|g' \
  -e 's|features/movement/screens/movement_amount_screen.dart|features/movement/presentation/shared/movement_amount_screen.dart|g' \
  -e 's|features/movement/widgets/amount_input_pad.dart|features/movement/presentation/shared/amount_input_pad.dart|g' \
  -e 's|features/movement/widgets/financial_status_badge.dart|features/movement/presentation/shared/financial_status_badge.dart|g' \
  -e 's|features/movement/widgets/internal_recent_avatar.dart|features/movement/presentation/shared/internal_recent_avatar.dart|g' \
  -e 's|features/movement/widgets/lightning_keypad.dart|features/movement/presentation/shared/lightning_keypad.dart|g' \
  -e 's|features/movement/widgets/lightning_top_bar.dart|features/movement/presentation/shared/lightning_top_bar.dart|g' \
  -e 's|features/movement/widgets/movement_confirmation_surface.dart|features/movement/presentation/shared/movement_confirmation_surface.dart|g' \
  -e 's|features/movement/widgets/quick_contact_list.dart|features/movement/presentation/shared/quick_contact_list.dart|g' \
  -e 's|features/movement/flow/movement_flow_coordinator.dart|features/movement/kernel/routing/movement_flow_coordinator.dart|g' \
  -e 's|features/movement/flow/kfe_receiving_capabilities_service.dart|features/movement/data/kfe_receiving_capabilities_service.dart|g' \
  -e 's|features/movement/domain/entities/|features/movement/data/entities/|g' \
  -e 's|features/movement/domain/repositories/|features/movement/data/repositories/|g' \
  -e 's|features/movement/domain/payment_intent|features/movement/kernel/intent/payment_intent|g' \
  -e 's|features/movement/domain/|features/movement/data/|g' \
  -e 's|features/movement/utils/|features/movement/data/|g'

echo "Migration script completed."
