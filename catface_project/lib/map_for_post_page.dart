import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapForPostPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapForPostPage({Key? key, this.initialLat, this.initialLng})
    : super(key: key);

  @override
  _MapForPostPageState createState() => _MapForPostPageState();
}

class _MapForPostPageState extends State<MapForPostPage> {
  GoogleMapController? _controller;
  late LatLng _selectedLatLng;

  @override
  void initState() {
    super.initState();
    // หากมีค่า initial ให้ใช้ ถ้าไม่ ให้ใช้ค่า default (เช่นกรุงเทพฯ)
    _selectedLatLng =
        widget.initialLat != null && widget.initialLng != null
            ? LatLng(widget.initialLat!, widget.initialLng!)
            : const LatLng(13.7563, 100.5018);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        title: Text("Select Location", style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              // เมื่อกด Confirm ส่งค่า _selectedLatLng กลับไป
              Navigator.pop(context, _selectedLatLng);
            },
            child: const Text(
              "Confirm",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _selectedLatLng,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          _controller = controller;
        },
        // อัพเดทตำแหน่ง marker เมื่อผู้ใช้เลื่อนแผนที่
        onCameraMove: (position) {
          setState(() {
            _selectedLatLng = position.target;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId("selected-location"),
            position: _selectedLatLng,
            draggable: true,
            onDragEnd: (newPosition) {
              setState(() {
                _selectedLatLng = newPosition;
              });
            },
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
