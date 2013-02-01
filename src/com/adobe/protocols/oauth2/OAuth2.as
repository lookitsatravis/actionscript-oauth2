package com.adobe.protocols.oauth2
{
	import com.adobe.protocols.oauth2.event.GetAccessTokenEvent;
	import com.adobe.protocols.oauth2.event.RefreshAccessTokenEvent;
	import com.adobe.protocols.oauth2.grant.AuthorizationCodeGrant;
	import com.adobe.protocols.oauth2.grant.IGrantType;
	import com.adobe.protocols.oauth2.grant.ImplicitGrant;
	import com.adobe.protocols.oauth2.grant.ResourceOwnerCredentialsGrant;
	import com.adobe.serialization.json.JSONParseError;
	import com.unicore.util.Logger;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.LocationChangeEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;

	/**
	 * Event that is broadcast when results from a <code>getAccessToken</code> request are received.
	 * 
	 * @eventType com.adobe.protocols.oauth2.event.GetAccessTokenEvent.TYPE
	 * 
	 * @see #getAccessToken()
	 * @see com.adobe.protocols.oauth2.event.GetAccessTokenEvent
	 */
	[Event(name="getAccessToken", type="com.adobe.protocols.oauth2.event.GetAccessTokenEvent")]
	
	/**
	 * Event that is broadcast when results from a <code>refreshAccessToken</code> request are received.
	 * 
	 * @eventType com.adobe.protocols.oauth2.event.RefreshAccessTokenEvent.TYPE
	 * 
	 * @see #refreshAccessToken()
	 * @see com.adobe.protocols.oauth2.event.RefreshAccessTokenEvent
	 */
	[Event(name="refreshAccessToken", type="com.adobe.protocols.oauth2.event.RefreshAccessTokenEvent")]
	
	/**
	 * Utility class the encapsulates APIs for interaction with an OAuth 2.0 server.
	 * Implemented against the OAuth 2.0 v2.15 specification.
	 * 
	 * @see http://tools.ietf.org/html/draft-ietf-oauth-v2-15
	 * 
	 * @author Charles Bihis (www.whoischarles.com)
	 */
	public class OAuth2 extends EventDispatcher
	{		
		private var grantType:IGrantType;
		private var authEndpoint:String;
		private var tokenEndpoint:String;		
		
		/**
		 * Constructor to create a valid OAuth2 client object.
		 * 
		 * @param authEndpoint The authorization endpoint used by the OAuth 2.0 server
		 * @param tokenEndpoint The token endpoint used by the OAuth 2.0 server
		 * @param logLevel (Optional) The new log level for the logger to use
		 */
		public function OAuth2(authEndpoint:String, tokenEndpoint:String)
		{
			// save endpoint properties
			this.authEndpoint = authEndpoint;
			this.tokenEndpoint = tokenEndpoint;
		} // OAuth2
		
		/**
		 * Initiates the access token request workflow with the proper context as
		 * described by the passed-in grant-type object.  Upon completion, will
		 * dispatch a <code>GetAccessTokenEvent</code> event.
		 * 
		 * @param grantType An <code>IGrantType</code> object which represents the desired workflow to use when requesting an access token
		 * 
		 * @see com.adobe.protocols.oauth2.grant.IGrantType
		 * @see com.adobe.protocols.oauth2.event.GetAccessTokenEvent#TYPE
		 */
		public function getAccessToken(grantType:IGrantType):void
		{
			if (grantType is AuthorizationCodeGrant)
			{
				Logger.info("Oauth2.getAccessToken(): Initiating getAccessToken() with authorization code grant type workflow");
				getAccessTokenWithAuthorizationCodeGrant(grantType as AuthorizationCodeGrant);
			}  // if statement
			else if (grantType is ImplicitGrant)
			{
				Logger.info("Oauth2.getAccessToken(): Initiating getAccessToken() with implicit grant type workflow");
				getAccessTokenWithImplicitGrant(grantType as ImplicitGrant);
			}  // else-if statement
			else if (grantType is ResourceOwnerCredentialsGrant)
			{
				Logger.info("Oauth2.getAccessToken(): Initiating getAccessToken() with resource owner credentials grant type workflow");
				getAccessTokenWithResourceOwnerCredentialsGrant(grantType as ResourceOwnerCredentialsGrant);
			}  // else-if statement
		}  // getAccessToken
		
		/**
		 * Initiates request to refresh a given access token.  Upon completion, will dispatch
		 * a <code>RefreshAccessTokenEvent</code> event.  On success, a new refresh token may
		 * be issues, at which point the client should discard the old refresh token with the
		 * new one.
		 * 
		 * @param refreshToken A valid refresh token received during last request for an access token
		 * @param clientId The client identifier
		 * @param clientSecret The client secret
		 * 
		 * @see com.adobe.protocols.oauth2.event.RefreshAccessTokenEvent#TYPE
		 */
		public function refreshAccessToken(refreshToken:String, clientId:String, clientSecret:String, scope:String = null):void
		{
			// create result event
			var refreshAccessTokenEvent:RefreshAccessTokenEvent = new RefreshAccessTokenEvent();
			
			// set up URL request
			var urlRequest:URLRequest = new URLRequest(tokenEndpoint);
			var urlLoader:URLLoader = new URLLoader();
			urlRequest.method = URLRequestMethod.POST;
			
			// define POST parameters
			var urlVariables : URLVariables = new URLVariables();  
			urlVariables.grant_type = "refresh_token"; 
			urlVariables.client_id = clientId;
			urlVariables.client_secret = clientSecret;
			urlVariables.refresh_token = refreshToken;
			urlVariables.scope = scope;
			urlRequest.data = urlVariables;
			
			// attach event listeners
			urlLoader.addEventListener(Event.COMPLETE, onRefreshAccessTokenResult);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onRefreshAccessTokenError);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onRefreshAccessTokenError);
			
			// make the call
			try
			{
				urlLoader.load(urlRequest);
			}  // try statement
			catch (error:Error)
			{
				Logger.error("Oauth2.refreshAccessToken() Error loading token endpoint \"" + tokenEndpoint + "\"");
			}  // catch statement
			
			function onRefreshAccessTokenResult(event:Event):void
			{
				try
				{
					var response:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
					Logger.error("Oauth2.refreshAccessToken() Access token: " + response.access_token);
					refreshAccessTokenEvent.parseAccessTokenResponse(response);
				}  // try statement
				catch (error:JSONParseError)
				{
					refreshAccessTokenEvent.errorCode = "com.adobe.serialization.json.JSONParseError";
					refreshAccessTokenEvent.errorMessage = "Error parsing output from refresh access token response";					
				}  // catch statement
				
				dispatchEvent(refreshAccessTokenEvent);
			}  // onRefreshAccessTokenResult
			
			function onRefreshAccessTokenError(event:Event):void
			{
				Logger.error("Oauth2.refreshAccessToken() Error encountered during refresh access token request: " + event);
				
				try
				{
					var error:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
					refreshAccessTokenEvent.errorCode = error.error;
					refreshAccessTokenEvent.errorMessage = error.error_description;
				}  // try statement
				catch (error:JSONParseError)
				{
					refreshAccessTokenEvent.errorCode = "Unknown";
					refreshAccessTokenEvent.errorMessage = "Error encountered during refresh access token request.  Unable to parse error message.";
				}  // catch statement
				
				dispatchEvent(refreshAccessTokenEvent);
			}  // onRefreshAccessTokenError
		}  // refreshAccessToken
		
		/**
		 * @private
		 * 
		 * Helper function that completes get-access-token request using the authorization code grant type.
		 */
		private function getAccessTokenWithAuthorizationCodeGrant(authorizationCodeGrant:AuthorizationCodeGrant):void
		{
			// create result event
			var getAccessTokenEvent:GetAccessTokenEvent = new GetAccessTokenEvent();
			
			// add event listeners
			authorizationCodeGrant.stageWebView.addEventListener(LocationChangeEvent.LOCATION_CHANGING, onLocationChanging);
			authorizationCodeGrant.stageWebView.addEventListener(LocationChangeEvent.LOCATION_CHANGE, onLocationChanging);
			authorizationCodeGrant.stageWebView.addEventListener(Event.COMPLETE, onStageWebViewComplete);
			authorizationCodeGrant.stageWebView.addEventListener(ErrorEvent.ERROR, onStageWebViewError);
			
			// start the auth process
			var startTime:Number = new Date().time;
			Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Loading auth URL: " + authorizationCodeGrant.getFullAuthUrl(authEndpoint));
			authorizationCodeGrant.stageWebView.loadURL(authorizationCodeGrant.getFullAuthUrl(authEndpoint));
			
			function onLocationChanging(locationChangeEvent:LocationChangeEvent):void
			{
				Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Loading URL: " + locationChangeEvent.location);
				if (locationChangeEvent.location.indexOf(authorizationCodeGrant.redirectUri) == 0)
				{
					Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Redirect URI encountered (" + authorizationCodeGrant.redirectUri + ").  Extracting values from path.");
					
					// stop event from propogating
					locationChangeEvent.preventDefault();
					
					// determine if authorization was successful
					var queryParams:Object = extractQueryParams(locationChangeEvent.location);
					var code:String = queryParams.code;		// authorization code
					if (code != null)
					{
						Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Authorization code: " + code);
						
						// set up URL request
						var urlRequest:URLRequest = new URLRequest(tokenEndpoint);
						var urlLoader:URLLoader = new URLLoader();
						urlRequest.method = URLRequestMethod.POST;
						
						// define POST parameters
						var urlVariables : URLVariables = new URLVariables();  
						urlVariables.grant_type = "authorization_code"; 
						urlVariables.code = code;
						urlVariables.redirect_uri = authorizationCodeGrant.redirectUri;
						urlVariables.client_id = authorizationCodeGrant.clientId;
						urlVariables.client_secret = authorizationCodeGrant.clientSecret;
						urlRequest.data = urlVariables;
						
						// attach event listeners
						urlLoader.addEventListener(Event.COMPLETE, onGetAccessTokenResult);
						urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onGetAccessTokenError);
						urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onGetAccessTokenError);
						
						// make the call
						try
						{
							urlLoader.load(urlRequest);
						}  // try statement
						catch (error:Error)
						{
							Logger.error("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Error loading token endpoint \"" + tokenEndpoint + "\"");
						}  // catch statement
					}  // if statement
					else
					{
						Logger.error("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Error encountered during authorization request");
						getAccessTokenEvent.errorCode = queryParams.error;
						getAccessTokenEvent.errorMessage = queryParams.error_description;
						dispatchEvent(getAccessTokenEvent);
					}  // else statement
				}  // if statement
				
				function onGetAccessTokenResult(event:Event):void
				{
					try
					{
						var response:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
						Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Access token: " + response.access_token);
						getAccessTokenEvent.parseAccessTokenResponse(response);
					}  // try statement
					catch (error:JSONParseError)
					{
						getAccessTokenEvent.errorCode = "com.adobe.serialization.json.JSONParseError";
						getAccessTokenEvent.errorMessage = "Error parsing output from access token response";
					}  // catch statement
					
					dispatchEvent(getAccessTokenEvent);
				}  // onGetAccessTokenResult
				
				function onGetAccessTokenError(event:Event):void
				{
					Logger.error("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Error encountered during access token request: " + event);
					
					try
					{
						var error:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
						getAccessTokenEvent.errorCode = error.error;
						getAccessTokenEvent.errorMessage = error.error_description;
					}  // try statement
					catch (error:JSONParseError)
					{
						getAccessTokenEvent.errorCode = "Unknown";
						getAccessTokenEvent.errorMessage = "Error encountered during access token request.  Unable to parse error message.";
					}  // catch statement
					
					dispatchEvent(getAccessTokenEvent);
				}  // onGetAccessTokenError
			}  // onLocationChange
			
			function onStageWebViewComplete(event:Event):void
			{
				Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Auth URL loading complete after " + (new Date().time - startTime) + "ms");
			}  // onStageWebViewComplete
			
			function onStageWebViewError(event:ErrorEvent):void
			{
				Logger.info("Oauth2.getAccessTokenWithAuthorizationCodeGrant() Error occurred with StageWebView: " + event);
				getAccessTokenEvent.errorCode = "STAGE_WEB_VIEW_ERROR";
				getAccessTokenEvent.errorMessage = "Error occurred with StageWebView";
				dispatchEvent(getAccessTokenEvent);
			}  // onStageWebViewError
		}  // getAccessTokenWithAuthorizationCodeGrant
		
		/**
		 * @private
		 * 
		 * Helper function that completes get-access-token request using the implicit grant type.
		 */
		private function getAccessTokenWithImplicitGrant(implicitGrant:ImplicitGrant):void
		{
			// create result event
			var getAccessTokenEvent:GetAccessTokenEvent = new GetAccessTokenEvent();
			
			// add event listeners
			implicitGrant.stageWebView.addEventListener(LocationChangeEvent.LOCATION_CHANGING, onLocationChange);
			implicitGrant.stageWebView.addEventListener(LocationChangeEvent.LOCATION_CHANGE, onLocationChange);
			implicitGrant.stageWebView.addEventListener(ErrorEvent.ERROR, onStageWebViewError);
			
			// start the auth process
			Logger.info("Oauth2.getAccessTokenWithImplicitGrant() Loading auth URL: " + implicitGrant.getFullAuthUrl(authEndpoint));
			implicitGrant.stageWebView.loadURL(implicitGrant.getFullAuthUrl(authEndpoint));
			
			function onLocationChange(event:LocationChangeEvent):void
			{
				Logger.info("Oauth2.getAccessTokenWithImplicitGrant() Loading URL: " + event.location);
				if (event.location.indexOf(implicitGrant.redirectUri) == 0)
				{
					Logger.info("Oauth2.getAccessTokenWithImplicitGrant() Redirect URI encountered (" + implicitGrant.redirectUri + ").  Extracting values from path.");
					
					// stop event from propogating
					event.preventDefault();
					
					// determine if authorization was successful
					var queryParams:Object = extractQueryParams(event.location);
					var accessToken:String = queryParams.access_token;
					if (accessToken != null)
					{
						Logger.info("Oauth2.getAccessTokenWithImplicitGrant() Access token: " + accessToken);
						getAccessTokenEvent.parseAccessTokenResponse(queryParams);
						dispatchEvent(getAccessTokenEvent);
					}  // if statement
					else
					{
						Logger.error("Oauth2.getAccessTokenWithImplicitGrant() Error encountered during access token request");
						getAccessTokenEvent.errorCode = queryParams.error;
						getAccessTokenEvent.errorMessage = queryParams.error_description;
						dispatchEvent(getAccessTokenEvent);
					}  // else statement
				}  // if statement
			}  // onLocationChange
			
			function onStageWebViewError(event:ErrorEvent):void
			{
				Logger.error("Oauth2.getAccessTokenWithImplicitGrant() Error occurred with StageWebView: " + event);
				getAccessTokenEvent.errorCode = "STAGE_WEB_VIEW_ERROR";
				getAccessTokenEvent.errorMessage = "Error occurred with StageWebView";
				dispatchEvent(getAccessTokenEvent);
			}  // onStageWebViewError
		}  // getAccessTokenWithImplicitGrant
		
		/**
		 * @private
		 * 
		 * Helper function that completes get-access-token request using the resource owner password credentials grant type.
		 */
		private function getAccessTokenWithResourceOwnerCredentialsGrant(resourceOwnerCredentialsGrant:ResourceOwnerCredentialsGrant):void
		{
			// create result event
			var getAccessTokenEvent:GetAccessTokenEvent = new GetAccessTokenEvent();
			
			// set up URL request
			var urlRequest:URLRequest = new URLRequest(tokenEndpoint);
			var urlLoader:URLLoader = new URLLoader();
			urlRequest.method = URLRequestMethod.POST;
			urlRequest.contentType = "application/x-www-form-urlencoded";
			urlRequest.requestHeaders = [new URLRequestHeader("Accept", "application/json")];
			
			// define POST parameters
			var urlVariables : URLVariables = new URLVariables();  
			urlVariables.grant_type = "password";
			urlVariables.client_id = resourceOwnerCredentialsGrant.clientId;
			urlVariables.client_secret = resourceOwnerCredentialsGrant.clientSecret;
			urlVariables.username = resourceOwnerCredentialsGrant.username;
			urlVariables.password = resourceOwnerCredentialsGrant.password;
			//if(resourceOwnerCredentialsGrant.scope) urlVariables.scope = resourceOwnerCredentialsGrant.scope;
			urlRequest.data = urlVariables;
			
			// attach event listeners
			urlLoader.addEventListener(Event.COMPLETE, onGetAccessTokenResult);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onGetAccessTokenError);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onGetAccessTokenError);
			
			// make the call
			try
			{
				urlLoader.load(urlRequest);
			}  // try statement
			catch (error:Error)
			{
				Logger.error("Oauth2.getAccessTokenWithResourceOwnerCredentialsGrant() Error loading token endpoint \"" + tokenEndpoint + "\"");
			}  // catch statement
			
			function onGetAccessTokenResult(event:Event):void
			{
				try
				{
					var response:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
					Logger.info("Oauth2.getAccessTokenWithResourceOwnerCredentialsGrant() Access token: " + response.access_token);
					Logger.info("Oauth2.getAccessTokenWithResourceOwnerCredentialsGrant() Instance URL: " + response.instance_url);
					getAccessTokenEvent.parseAccessTokenResponse(response);
				}  // try statement
				catch (error:JSONParseError)
				{
					getAccessTokenEvent.errorCode = "com.adobe.serialization.json.JSONParseError";
					getAccessTokenEvent.errorMessage = "Error parsing output from access token response";
				}  // catch statement
				
				dispatchEvent(getAccessTokenEvent);
			}  // onGetAccessTokenResult
			
			function onGetAccessTokenError(event:Event):void
			{
				Logger.error("Oauth2.getAccessTokenWithResourceOwnerCredentialsGrant() Error encountered during access token request: " + event);
				
				try
				{
					var error:Object = com.adobe.serialization.json.JSON.decode(event.target.data);
					getAccessTokenEvent.errorCode = error.error;
					getAccessTokenEvent.errorMessage = error.error_description;
				}  // try statement
				catch (error:JSONParseError)
				{
					getAccessTokenEvent.errorCode = "Unknown";
					getAccessTokenEvent.errorMessage = "Error encountered during access token request.  Unable to parse error message.";
				}  // catch statement
				
				dispatchEvent(getAccessTokenEvent);
			}  // onGetAccessTokenError
		}  // getAccessTokenWithResourceOwnerCredentialsGrant
		
		/**
		 * @private
		 * 
		 * Helper function to extract query from URL and URL fragment.
		 */
		private function extractQueryParams(url:String):Object
		{
			var delimiter:String = (url.indexOf("?") > 0) ? "?" : "#";
			var queryParamsString:String = url.split(delimiter)[1];
			var queryParamsArray:Array = queryParamsString.split("&");
			var queryParams:Object = new Object();
			
			for each (var queryParam:String in queryParamsArray)
			{
				var keyValue:Array = queryParam.split("=");
				queryParams[keyValue[0]] = keyValue[1];	
			}  // for loop
			
			return queryParams;
		}  // extractQueryParams
	}  // class declaration
}  // package