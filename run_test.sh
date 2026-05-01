#!/bin/bash
cd /home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-42

# Create test environment variables file
export TEST_ID="${TEST_ID:-test_user@koreatech.ac.kr}"
export TEST_PASSWORD="${TEST_PASSWORD:-testpass123}"
export TEST_ID_SUBSCRIBED="${TEST_ID_SUBSCRIBED:-test_subscribed@koreatech.ac.kr}"
export TEST_PASSWORD_SUBSCRIBED="${TEST_PASSWORD_SUBSCRIBED:-testpass456}"

# Run the flows one by one and capture results
results=()

for flow_file in callvan_notification_modal_confirm.yaml callvan_notification_modal_dismiss.yaml callvan_notification_modal_login_transition.yaml callvan_notification_modal_subscribed.yaml; do
  echo "Running $flow_file..."
  
  if ~/.maestro/bin/maestro test "$flow_file" \
    -e "TEST_ID=$TEST_ID" \
    -e "TEST_PASSWORD=$TEST_PASSWORD" \
    -e "TEST_ID_SUBSCRIBED=$TEST_ID_SUBSCRIBED" \
    -e "TEST_PASSWORD_SUBSCRIBED=$TEST_PASSWORD_SUBSCRIBED" \
    --format junit \
    --output "results/${flow_file%.yaml}_result.xml" 2>&1 | tee "results/${flow_file%.yaml}.log"; then
    results+=("$flow_file: PASS")
  else
    results+=("$flow_file: FAIL")
  fi
done

echo "=== Test Results ==="
for result in "${results[@]}"; do
  echo "$result"
done
