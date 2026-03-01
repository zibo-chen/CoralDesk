// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AgentEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AgentEvent()';
}


}

/// @nodoc
class $AgentEventCopyWith<$Res>  {
$AgentEventCopyWith(AgentEvent _, $Res Function(AgentEvent) __);
}


/// Adds pattern-matching-related methods to [AgentEvent].
extension AgentEventPatterns on AgentEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AgentEvent_Thinking value)?  thinking,TResult Function( AgentEvent_TextDelta value)?  textDelta,TResult Function( AgentEvent_ToolCallStart value)?  toolCallStart,TResult Function( AgentEvent_ToolCallEnd value)?  toolCallEnd,TResult Function( AgentEvent_ToolApprovalRequest value)?  toolApprovalRequest,TResult Function( AgentEvent_MessageComplete value)?  messageComplete,TResult Function( AgentEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AgentEvent_Thinking() when thinking != null:
return thinking(_that);case AgentEvent_TextDelta() when textDelta != null:
return textDelta(_that);case AgentEvent_ToolCallStart() when toolCallStart != null:
return toolCallStart(_that);case AgentEvent_ToolCallEnd() when toolCallEnd != null:
return toolCallEnd(_that);case AgentEvent_ToolApprovalRequest() when toolApprovalRequest != null:
return toolApprovalRequest(_that);case AgentEvent_MessageComplete() when messageComplete != null:
return messageComplete(_that);case AgentEvent_Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AgentEvent_Thinking value)  thinking,required TResult Function( AgentEvent_TextDelta value)  textDelta,required TResult Function( AgentEvent_ToolCallStart value)  toolCallStart,required TResult Function( AgentEvent_ToolCallEnd value)  toolCallEnd,required TResult Function( AgentEvent_ToolApprovalRequest value)  toolApprovalRequest,required TResult Function( AgentEvent_MessageComplete value)  messageComplete,required TResult Function( AgentEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case AgentEvent_Thinking():
return thinking(_that);case AgentEvent_TextDelta():
return textDelta(_that);case AgentEvent_ToolCallStart():
return toolCallStart(_that);case AgentEvent_ToolCallEnd():
return toolCallEnd(_that);case AgentEvent_ToolApprovalRequest():
return toolApprovalRequest(_that);case AgentEvent_MessageComplete():
return messageComplete(_that);case AgentEvent_Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AgentEvent_Thinking value)?  thinking,TResult? Function( AgentEvent_TextDelta value)?  textDelta,TResult? Function( AgentEvent_ToolCallStart value)?  toolCallStart,TResult? Function( AgentEvent_ToolCallEnd value)?  toolCallEnd,TResult? Function( AgentEvent_ToolApprovalRequest value)?  toolApprovalRequest,TResult? Function( AgentEvent_MessageComplete value)?  messageComplete,TResult? Function( AgentEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case AgentEvent_Thinking() when thinking != null:
return thinking(_that);case AgentEvent_TextDelta() when textDelta != null:
return textDelta(_that);case AgentEvent_ToolCallStart() when toolCallStart != null:
return toolCallStart(_that);case AgentEvent_ToolCallEnd() when toolCallEnd != null:
return toolCallEnd(_that);case AgentEvent_ToolApprovalRequest() when toolApprovalRequest != null:
return toolApprovalRequest(_that);case AgentEvent_MessageComplete() when messageComplete != null:
return messageComplete(_that);case AgentEvent_Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  thinking,TResult Function( String text)?  textDelta,TResult Function( String name,  String args)?  toolCallStart,TResult Function( String name,  String result,  bool success)?  toolCallEnd,TResult Function( String requestId,  String name,  String args)?  toolApprovalRequest,TResult Function( BigInt? inputTokens,  BigInt? outputTokens)?  messageComplete,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AgentEvent_Thinking() when thinking != null:
return thinking();case AgentEvent_TextDelta() when textDelta != null:
return textDelta(_that.text);case AgentEvent_ToolCallStart() when toolCallStart != null:
return toolCallStart(_that.name,_that.args);case AgentEvent_ToolCallEnd() when toolCallEnd != null:
return toolCallEnd(_that.name,_that.result,_that.success);case AgentEvent_ToolApprovalRequest() when toolApprovalRequest != null:
return toolApprovalRequest(_that.requestId,_that.name,_that.args);case AgentEvent_MessageComplete() when messageComplete != null:
return messageComplete(_that.inputTokens,_that.outputTokens);case AgentEvent_Error() when error != null:
return error(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  thinking,required TResult Function( String text)  textDelta,required TResult Function( String name,  String args)  toolCallStart,required TResult Function( String name,  String result,  bool success)  toolCallEnd,required TResult Function( String requestId,  String name,  String args)  toolApprovalRequest,required TResult Function( BigInt? inputTokens,  BigInt? outputTokens)  messageComplete,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case AgentEvent_Thinking():
return thinking();case AgentEvent_TextDelta():
return textDelta(_that.text);case AgentEvent_ToolCallStart():
return toolCallStart(_that.name,_that.args);case AgentEvent_ToolCallEnd():
return toolCallEnd(_that.name,_that.result,_that.success);case AgentEvent_ToolApprovalRequest():
return toolApprovalRequest(_that.requestId,_that.name,_that.args);case AgentEvent_MessageComplete():
return messageComplete(_that.inputTokens,_that.outputTokens);case AgentEvent_Error():
return error(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  thinking,TResult? Function( String text)?  textDelta,TResult? Function( String name,  String args)?  toolCallStart,TResult? Function( String name,  String result,  bool success)?  toolCallEnd,TResult? Function( String requestId,  String name,  String args)?  toolApprovalRequest,TResult? Function( BigInt? inputTokens,  BigInt? outputTokens)?  messageComplete,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case AgentEvent_Thinking() when thinking != null:
return thinking();case AgentEvent_TextDelta() when textDelta != null:
return textDelta(_that.text);case AgentEvent_ToolCallStart() when toolCallStart != null:
return toolCallStart(_that.name,_that.args);case AgentEvent_ToolCallEnd() when toolCallEnd != null:
return toolCallEnd(_that.name,_that.result,_that.success);case AgentEvent_ToolApprovalRequest() when toolApprovalRequest != null:
return toolApprovalRequest(_that.requestId,_that.name,_that.args);case AgentEvent_MessageComplete() when messageComplete != null:
return messageComplete(_that.inputTokens,_that.outputTokens);case AgentEvent_Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class AgentEvent_Thinking extends AgentEvent {
  const AgentEvent_Thinking(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_Thinking);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AgentEvent.thinking()';
}


}




/// @nodoc


class AgentEvent_TextDelta extends AgentEvent {
  const AgentEvent_TextDelta({required this.text}): super._();
  

 final  String text;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_TextDeltaCopyWith<AgentEvent_TextDelta> get copyWith => _$AgentEvent_TextDeltaCopyWithImpl<AgentEvent_TextDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_TextDelta&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'AgentEvent.textDelta(text: $text)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_TextDeltaCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_TextDeltaCopyWith(AgentEvent_TextDelta value, $Res Function(AgentEvent_TextDelta) _then) = _$AgentEvent_TextDeltaCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$AgentEvent_TextDeltaCopyWithImpl<$Res>
    implements $AgentEvent_TextDeltaCopyWith<$Res> {
  _$AgentEvent_TextDeltaCopyWithImpl(this._self, this._then);

  final AgentEvent_TextDelta _self;
  final $Res Function(AgentEvent_TextDelta) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(AgentEvent_TextDelta(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AgentEvent_ToolCallStart extends AgentEvent {
  const AgentEvent_ToolCallStart({required this.name, required this.args}): super._();
  

 final  String name;
 final  String args;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_ToolCallStartCopyWith<AgentEvent_ToolCallStart> get copyWith => _$AgentEvent_ToolCallStartCopyWithImpl<AgentEvent_ToolCallStart>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_ToolCallStart&&(identical(other.name, name) || other.name == name)&&(identical(other.args, args) || other.args == args));
}


@override
int get hashCode => Object.hash(runtimeType,name,args);

@override
String toString() {
  return 'AgentEvent.toolCallStart(name: $name, args: $args)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_ToolCallStartCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_ToolCallStartCopyWith(AgentEvent_ToolCallStart value, $Res Function(AgentEvent_ToolCallStart) _then) = _$AgentEvent_ToolCallStartCopyWithImpl;
@useResult
$Res call({
 String name, String args
});




}
/// @nodoc
class _$AgentEvent_ToolCallStartCopyWithImpl<$Res>
    implements $AgentEvent_ToolCallStartCopyWith<$Res> {
  _$AgentEvent_ToolCallStartCopyWithImpl(this._self, this._then);

  final AgentEvent_ToolCallStart _self;
  final $Res Function(AgentEvent_ToolCallStart) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? args = null,}) {
  return _then(AgentEvent_ToolCallStart(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AgentEvent_ToolCallEnd extends AgentEvent {
  const AgentEvent_ToolCallEnd({required this.name, required this.result, required this.success}): super._();
  

 final  String name;
 final  String result;
 final  bool success;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_ToolCallEndCopyWith<AgentEvent_ToolCallEnd> get copyWith => _$AgentEvent_ToolCallEndCopyWithImpl<AgentEvent_ToolCallEnd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_ToolCallEnd&&(identical(other.name, name) || other.name == name)&&(identical(other.result, result) || other.result == result)&&(identical(other.success, success) || other.success == success));
}


@override
int get hashCode => Object.hash(runtimeType,name,result,success);

@override
String toString() {
  return 'AgentEvent.toolCallEnd(name: $name, result: $result, success: $success)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_ToolCallEndCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_ToolCallEndCopyWith(AgentEvent_ToolCallEnd value, $Res Function(AgentEvent_ToolCallEnd) _then) = _$AgentEvent_ToolCallEndCopyWithImpl;
@useResult
$Res call({
 String name, String result, bool success
});




}
/// @nodoc
class _$AgentEvent_ToolCallEndCopyWithImpl<$Res>
    implements $AgentEvent_ToolCallEndCopyWith<$Res> {
  _$AgentEvent_ToolCallEndCopyWithImpl(this._self, this._then);

  final AgentEvent_ToolCallEnd _self;
  final $Res Function(AgentEvent_ToolCallEnd) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? result = null,Object? success = null,}) {
  return _then(AgentEvent_ToolCallEnd(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class AgentEvent_ToolApprovalRequest extends AgentEvent {
  const AgentEvent_ToolApprovalRequest({required this.requestId, required this.name, required this.args}): super._();
  

 final  String requestId;
 final  String name;
 final  String args;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_ToolApprovalRequestCopyWith<AgentEvent_ToolApprovalRequest> get copyWith => _$AgentEvent_ToolApprovalRequestCopyWithImpl<AgentEvent_ToolApprovalRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_ToolApprovalRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.name, name) || other.name == name)&&(identical(other.args, args) || other.args == args));
}


@override
int get hashCode => Object.hash(runtimeType,requestId,name,args);

@override
String toString() {
  return 'AgentEvent.toolApprovalRequest(requestId: $requestId, name: $name, args: $args)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_ToolApprovalRequestCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_ToolApprovalRequestCopyWith(AgentEvent_ToolApprovalRequest value, $Res Function(AgentEvent_ToolApprovalRequest) _then) = _$AgentEvent_ToolApprovalRequestCopyWithImpl;
@useResult
$Res call({
 String requestId, String name, String args
});




}
/// @nodoc
class _$AgentEvent_ToolApprovalRequestCopyWithImpl<$Res>
    implements $AgentEvent_ToolApprovalRequestCopyWith<$Res> {
  _$AgentEvent_ToolApprovalRequestCopyWithImpl(this._self, this._then);

  final AgentEvent_ToolApprovalRequest _self;
  final $Res Function(AgentEvent_ToolApprovalRequest) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? name = null,Object? args = null,}) {
  return _then(AgentEvent_ToolApprovalRequest(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AgentEvent_MessageComplete extends AgentEvent {
  const AgentEvent_MessageComplete({this.inputTokens, this.outputTokens}): super._();
  

 final  BigInt? inputTokens;
 final  BigInt? outputTokens;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_MessageCompleteCopyWith<AgentEvent_MessageComplete> get copyWith => _$AgentEvent_MessageCompleteCopyWithImpl<AgentEvent_MessageComplete>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_MessageComplete&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens));
}


@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens);

@override
String toString() {
  return 'AgentEvent.messageComplete(inputTokens: $inputTokens, outputTokens: $outputTokens)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_MessageCompleteCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_MessageCompleteCopyWith(AgentEvent_MessageComplete value, $Res Function(AgentEvent_MessageComplete) _then) = _$AgentEvent_MessageCompleteCopyWithImpl;
@useResult
$Res call({
 BigInt? inputTokens, BigInt? outputTokens
});




}
/// @nodoc
class _$AgentEvent_MessageCompleteCopyWithImpl<$Res>
    implements $AgentEvent_MessageCompleteCopyWith<$Res> {
  _$AgentEvent_MessageCompleteCopyWithImpl(this._self, this._then);

  final AgentEvent_MessageComplete _self;
  final $Res Function(AgentEvent_MessageComplete) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? inputTokens = freezed,Object? outputTokens = freezed,}) {
  return _then(AgentEvent_MessageComplete(
inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as BigInt?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as BigInt?,
  ));
}


}

/// @nodoc


class AgentEvent_Error extends AgentEvent {
  const AgentEvent_Error({required this.message}): super._();
  

 final  String message;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentEvent_ErrorCopyWith<AgentEvent_Error> get copyWith => _$AgentEvent_ErrorCopyWithImpl<AgentEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentEvent_Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AgentEvent.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $AgentEvent_ErrorCopyWith<$Res> implements $AgentEventCopyWith<$Res> {
  factory $AgentEvent_ErrorCopyWith(AgentEvent_Error value, $Res Function(AgentEvent_Error) _then) = _$AgentEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$AgentEvent_ErrorCopyWithImpl<$Res>
    implements $AgentEvent_ErrorCopyWith<$Res> {
  _$AgentEvent_ErrorCopyWithImpl(this._self, this._then);

  final AgentEvent_Error _self;
  final $Res Function(AgentEvent_Error) _then;

/// Create a copy of AgentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AgentEvent_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
