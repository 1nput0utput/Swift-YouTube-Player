//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

import UIKit

public enum YouTubePlayerState: String {
    case Unstarted = "-1"
    case Ended = "0"
    case Playing = "1"
    case Paused = "2"
    case Buffering = "3"
    case Queued = "4"
}

public enum YouTubePlayerEvents: String {
    case YouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case Ready = "onReady"
    case StateChange = "onStateChange"
    case PlaybackQualityChange = "onPlaybackQualityChange"
}

public enum YouTubePlaybackQuality: String {
    case Small = "small"
    case Medium = "medium"
    case Large = "large"
    case HD720 = "hd720"
    case HD1080 = "hd1080"
    case HighResolution = "highres"
}

public protocol YouTubePlayerViewDelegate {
    func playerReady(videoPlayer: YouTubePlayerView)
    func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
    func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
}

private extension NSURL {
    func queryStringComponents() -> [String: AnyObject] {

        var dict = [String: AnyObject]()

        // Check for query string
        if let query = self.query {

            // Loop through pairings (separated by &)
            for pair in query.componentsSeparatedByString("&") {

                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.componentsSeparatedByString("=")
                dict[components[0]] = components[1]
            }

        }

        return dict
    }
}

public class YouTubePlayerView: UIView, UIWebViewDelegate {

    typealias PlayerParameters = [String: AnyObject]

    var webView: UIWebView!

    // False until YouTubeIframeAPIReady
    public var ready = false

    /** The current state of the video player */
    public var playerState = YouTubePlayerState.Unstarted

    /** The current playback quality of the video player */
    public var playbackQuality = YouTubePlaybackQuality.Small

    public var delegate: YouTubePlayerViewDelegate?

    // MARK: Various methods for initialization

    override public init() {
        super.init()
        buildWebView(playerParameters())
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(playerParameters())
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(playerParameters())
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        // Remove web view in case it's within view hierarchy, reset frame, add as subview
        webView.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }


    // MARK: Web view initialization

    private func buildWebView(parameters: [String: AnyObject]) {
        webView = UIWebView()
        webView.allowsInlineMediaPlayback = true
        webView.mediaPlaybackRequiresUserAction = false
        webView.delegate = self
    }

    // MARK: Player controls

    public func loadPlayerWithVideoID(videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID

        loadWebViewWithParameters(playerParams)
    }

    public func play() {
        evaluatePlayerCommand("playVideo()")
    }

    public func pause() {
        evaluatePlayerCommand("pauseVideo()")
    }

    public func stop() {
        evaluatePlayerCommand("stopVideo()")
    }

    public func clear() {
        evaluatePlayerCommand("clearVideo()")
    }

    public func seekTo(seconds: Float, seekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
    }

    private func evaluatePlayerCommand(command: String) {
        let fullCommand = "player." + command + ";"
        webView.stringByEvaluatingJavaScriptFromString(fullCommand)
    }

    // MARK: Player setup

    private func loadWebViewWithParameters(parameters: PlayerParameters) {

        // Get HTML from player file in bundle
        let rawHTMLString = htmlStringWithFilePath(playerHTMLPath())!

        // Get JSON serialized parameters string
        let jsonParameters = serializedJSON(parameters)!

        // Replace %@ in rawHTMLString with jsonParameters string
        let htmlString = rawHTMLString.stringByReplacingOccurrencesOfString("%@", withString: jsonParameters, options: nil, range: nil)

        // Load HTML in web view
        webView.loadHTMLString(htmlString, baseURL: NSURL(string: "about:blank"))
    }

    private func playerHTMLPath() -> String {
        return NSBundle(forClass: self.classForCoder).pathForResource("YTPlayer", ofType: "html")!
    }

    private func htmlStringWithFilePath(path: String) -> String? {

        // Error optional for error handling
        var error: NSError?

        // Get HTML string from path
        let htmlString = NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: &error)

        // Check for error
        if let error = error {
            println("Lookup error: no HTML file found for path, \(path)")
        }

        return htmlString!
    }


    // MARK: Player parameters and defaults

    private func playerParameters() -> PlayerParameters {

        // Fetch default playerVars
        var playerVars = defaultPlayerVars()

        return [
            "height": "100%",
            "width": "100%",
            "events": playerCallbacks(),
            "playerVars": playerVars
        ]
    }

    private func defaultPlayerVars() -> PlayerParameters {
        return [
            "playsinline": 1,
            "controls": 0,
            "autoplay": 1,
            "disablekb": 1,
            "rel": 0,
            "modestbranding": 1,
            "showinfo": 0
        ]
    }

    private func playerCallbacks() -> PlayerParameters {
        return [
            "onReady": "onReady",
            "onStateChange": "onStateChange",
            "onPlaybackQualityChange": "onPlaybackQualityChange",
            "onError": "onPlayerError"
        ]
    }

    private func serializedJSON(object: AnyObject) -> String? {

        // Empty error
        var error: NSError?

        // Serialize json into NSData
        let jsonData = NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions.PrettyPrinted, error: &error)

        // Check for error and return nil
        if let error = error {
            println("Error parsing JSON")
            return nil
        }

        // Success, return JSON string
        return NSString(data: jsonData!, encoding: NSUTF8StringEncoding)
    }


    // MARK: JS Event Handling

    private func handleJSEvent(eventURL: NSURL) {

        // Grab the last component of the queryString as string
        let data: String? = eventURL.queryStringComponents()["data"] as? String

        if let host = eventURL.host {
            if let event = YouTubePlayerEvents(rawValue: host) {
                // Check event type and handle accordingly
                switch event {
                    case .YouTubeIframeAPIReady:
                        ready = true
                        break

                    case .Ready:
                        delegate?.playerReady(self)

                        break

                    case .StateChange:
                        if let newState = YouTubePlayerState(rawValue: data!) {
                            playerState = newState
                            delegate?.playerStateChanged(self, playerState: newState)
                        }

                        break

                    case .PlaybackQualityChange:
                        if let newQuality = YouTubePlaybackQuality(rawValue: data!) {
                            playbackQuality = newQuality
                            delegate?.playerQualityChanged(self, playbackQuality: newQuality)
                        }

                        break

                    default:
                        break
                }
            }
        }
    }


    // MARK: UIWebViewDelegate

    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {

        let url = request.URL

        // Check if ytplayer event and, if so, pass to handleJSEvent
        if url.scheme == "ytplayer" { handleJSEvent(url) }

        return true
    }
}
