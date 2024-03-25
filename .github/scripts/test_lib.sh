set -eo pipefail

xcodebuild -workspace Example/HTTPTaskPublisher.xcworkspace \
            -scheme HTTPTaskPublisher-Example \
            -destination platform=iOS\ Simulator,OS=17.2,name=iPhone\ 15 \
            clean test | xcpretty