// NativeRPCMessage.kt
// NativeRPC v2
//
// Core message types for the NativeRPC protocol

package com.itoken.team.nativerpc.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import java.util.UUID

/**
 * The type of RPC message
 */
@Serializable
enum class NativeRPCMessageType {
    @SerialName("call") CALL,
    @SerialName("result") RESULT,
    @SerialName("error") ERROR,
    @SerialName("event") EVENT,
    @SerialName("subscribe") SUBSCRIBE,
    @SerialName("unsubscribe") UNSUBSCRIBE
}

/**
 * An RPC request message from client to native
 */
@Serializable
data class NativeRPCRequest(
    val id: String = UUID.randomUUID().toString(),
    val type: NativeRPCMessageType = NativeRPCMessageType.CALL,
    val service: String,
    val method: String,
    val args: List<JsonElement> = emptyList()
)

/**
 * An RPC response message from native to client
 */
@Serializable
data class NativeRPCResponse(
    val id: String,
    val type: NativeRPCMessageType,
    val data: JsonElement? = null,
    val error: NativeRPCErrorInfo? = null
) {
    companion object {
        fun success(id: String, data: JsonElement?): NativeRPCResponse {
            return NativeRPCResponse(
                id = id,
                type = NativeRPCMessageType.RESULT,
                data = data
            )
        }
        
        fun error(id: String, error: NativeRPCError): NativeRPCResponse {
            return NativeRPCResponse(
                id = id,
                type = NativeRPCMessageType.ERROR,
                error = NativeRPCErrorInfo.from(error)
            )
        }
    }
}

/**
 * An event message from native to client
 */
@Serializable
data class NativeRPCEvent(
    val type: NativeRPCMessageType = NativeRPCMessageType.EVENT,
    val service: String,
    val event: String,
    val data: JsonElement? = null
)

/**
 * A subscription request message
 */
@Serializable
data class NativeRPCSubscription(
    val id: String = UUID.randomUUID().toString(),
    val type: NativeRPCMessageType,
    val service: String,
    val event: String
) {
    companion object {
        fun subscribe(service: String, event: String): NativeRPCSubscription {
            return NativeRPCSubscription(
                type = NativeRPCMessageType.SUBSCRIBE,
                service = service,
                event = event
            )
        }
        
        fun unsubscribe(service: String, event: String): NativeRPCSubscription {
            return NativeRPCSubscription(
                type = NativeRPCMessageType.UNSUBSCRIBE,
                service = service,
                event = event
            )
        }
    }
}

/**
 * Error information in response
 */
@Serializable
data class NativeRPCErrorInfo(
    val code: String,
    val message: String,
    val details: JsonElement? = null
) {
    companion object {
        fun from(error: NativeRPCError): NativeRPCErrorInfo {
            return NativeRPCErrorInfo(
                code = error.code,
                message = error.message,
                details = error.details
            )
        }
    }
}
