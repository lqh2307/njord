package io.madrona.njord.network

import io.madrona.njord.model.*

data class NetworkResponse<T>(
    val url: String? = null,
    val ok: Boolean,
    val body: T? = null,
    val status: Short? = null,
    val statusText: String? = null,
    val error: Exception? = null
)

fun <T, R> NetworkResponse<T>.map(mapper: (T) -> R) : NetworkResponse<R> {
    return body?.let {
        NetworkResponse(url, ok, mapper(it), status, statusText, error)
    } ?: NetworkResponse(url, ok, null, status, statusText, error)
}


internal expect suspend inline fun <reified T> Network.get(api: String, params: Map<String, String>? = null): NetworkResponse<T>
internal expect suspend inline fun <reified T, reified R> Network.post(api: String, item: T, params: Map<String, String>? = null): NetworkResponse<R>
internal expect suspend fun Network.delete(api: String, params: Map<String, String>): NetworkResponse<Unit>

object Network {


    suspend fun getS57Objects(): NetworkResponse<Map<String, S57Object>> = get("about/s57objects")
    suspend fun getAttributes(): NetworkResponse<Map<String, S57Attribute>> = get("about/s57attributes")
    suspend fun getExpectedInputs(): NetworkResponse<Map<String, List<S57ExpectedInput>>> = get("about/expectedInput")
    suspend fun getColors(): NetworkResponse<Map<ThemeMode, Map<Color, String>>> = get("about/colors")
    suspend fun getAbout() : NetworkResponse<AboutJson> = get("about/version")
    suspend fun getChartInfo(id: String) : NetworkResponse<Chart> = get("chart", mapOf("id" to id))
    suspend fun getCustomColors() : NetworkResponse<Map<String, Map<String, Map<String, String>>>> = get("about/colors/custom")
    suspend fun getChartCatalog(id: Long): NetworkResponse<ChartCatalog> = get("chart_catalog", mapOf("id" to "$id"))
    suspend fun getAdmin(): NetworkResponse<AdminResponse> = get("admin")
    suspend fun getSpriteSheet(themeMode: ThemeMode): NetworkResponse<Map<Sprite, IconInfo>> = get("content/sprites/${themeMode.name.lowercase()}_simplified@2x.json")
    suspend fun getFeatureByLayer(layer: String, startId: Long = 0L): NetworkResponse<LayerQueryResultPage> = get("feature/layer/$layer", mapOf("start_id" to "$startId"))
    suspend fun getFeatureByLnam(lnam: String, startId: Long = 0L): NetworkResponse<LayerQueryResultPage> = get("feature/lnam/$lnam", mapOf("start_id" to "$startId"))
    suspend fun verifyAdmin(signature: AdminSignature): NetworkResponse<AdminResponse> = post("admin/verify", signature)
    suspend fun deleteChart(signature: AdminResponse, id: Long): NetworkResponse<Unit> = delete("/chart", mapOf("id" to "$id", "signature" to signature.signatureEncoded))
}
