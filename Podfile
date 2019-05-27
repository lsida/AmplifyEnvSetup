# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'AmplifyTest' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
#  Cocoa Touch Frameworks
#  They are always open-source and will be built just like your app. (So Xcode will sometimes compile it, when you run your app and always after you cleaned the project.) Frameworks only support iOS 8 and newer, but you can use Swift and Objective-C in the framework.
#
#  Cocoa Touch Static Libraries
#  As the name says, they are static. So they are already compiled, when you import them to your project. You can share them with others without showing them your code. Note that Static Libraries currently don't support Swift. You will have to use Objective-C within the library. The app itself can still be written in Swift.
  use_frameworks!

  pod 'AWSCore', '~> 2.9.0'
  pod 'AWSAppSync', '~> 2.10.0'
  
  pod 'AWSMobileClient', '~> 2.9.0'      # Required dependency
  pod 'AWSAuthUI', '~> 2.9.0'            # Optional dependency required to use drop-in UI
  pod 'AWSUserPoolsSignIn', '~> 2.9.0'
  
  pod 'AWSPinpoint', '~> 2.9.0'
  
  pod 'IQKeyboardManager'
  
  
  # old sdk
  pod 'AWSCognito'
  pod 'AWSCognitoIdentityProvider'
#  pod 'GoogleSignIn'

  # Pods for AmplifyTest

  target 'AmplifyTestTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'AmplifyTestUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end
