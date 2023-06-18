set -eo pipefail

xcodebuild -workspace Example/HTTPTaskPublisher.xcworkspace \
            -scheme HTTPTaskPublisher-Example \
            -destination platform=iOS\ Simulator,OS=16.4,name=iPhone\ 14 \
            clean test | xcpretty