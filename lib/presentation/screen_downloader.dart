import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path/path.dart' as p;



class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  
  final _urlLink = TextEditingController();
  String downloadDirectory = '';
  int progress = 0;

  bool isDownloading = false;
  bool manifestLoading = false;
  
  List video = [];

  @override
  void initState() {

    super.initState();

    try {
      // For sharing or opening urls/text coming from outside the app while the app is in the memory
      ReceiveSharingIntent.getTextStream().listen((String value) {

        setState(() {
          _urlLink.text = value;
        });

        getAvailableResolutions(_urlLink.text);

      }, onError: (err) {
        debugPrint("$err");
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then((String? value) {

        if(value == null) return;

        setState(() {
          _urlLink.text = value;
        });

        getAvailableResolutions(_urlLink.text);
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }finally {
      initDownloadDirectory();
    }

  }

  Future<void> initDownloadDirectory() async {

    // 
    try {
      String path = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
      var downloadDir = await Directory('$path/YoutubeDownloaderMobile').create(recursive: true);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(downloadDir.path)));

      setState(() {
        downloadDirectory = downloadDir.path;
      });

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      try {
        final downloadDir = await getDownloadsDirectory();

        await Directory('${downloadDir!.path}/YoutubeDownloaderDesktop').create(recursive: true);

        setState(() {
          downloadDirectory = p.join(downloadDir.path, 'YoutubeDownloaderDesktop');
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String? getYoutubeThumbnail(String videoUrl) {
    final Uri? uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return null;
    }
    // To get a 16:9 version of the image, replace the /0 with /mqdefault 
    return 'https://img.youtube.com/vi/${uri.queryParameters['v'] ?? uri.pathSegments[0] }/0.jpg';
  }

  // get Stream manifest from the video with catching error
  Future getManifest(String videoUrl) async {

    try {
      setState(() {
        manifestLoading = true;
      });

      final YoutubeExplode yt = YoutubeExplode();
      final StreamManifest manifest = await yt.videos.streamsClient.getManifest(videoUrl);

      yt.close();

      setState(() {
        manifestLoading = false;
      });

      return manifest;

    }catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
    
  }

  void getAvailableResolutions(String videoUrl) async {

    setState(() {
      video.clear();
    });

    final YoutubeExplode yt = YoutubeExplode();
    final StreamManifest manifest = await getManifest(videoUrl);

    // Available Video (Muxed)
    Iterator<MuxedStreamInfo> iterator = manifest.muxed.iterator;
    while (iterator.moveNext()) {
      setState(() {
        video.add(iterator.current);
      });
    }

    yt.close();
  }

  void downloadvideo(int index) async {

    setState(() {
      isDownloading = true;
    });

    final yt = YoutubeExplode();
    final video = await yt.videos.get(_urlLink);

    final manifest = await yt.videos.streamsClient.getManifest(_urlLink);

    try {
      await Permission.storage.request();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    // Muxed
    final muxedStreams = manifest.muxed;

    // Get the muxed track with the highest bitrate.
    final muxed = muxedStreams.elementAt(index);

    final muxedStream = yt.videos.streamsClient.get(muxed);

    // Compose the file name removing the unallowed characters in windows.
    final fileName = '${video.title}.${muxed.container.name}'
        .replaceAll(r'\', '')
        .replaceAll('/', '')
        .replaceAll('*', '')
        .replaceAll('?', '')
        .replaceAll('"', '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('|', '');


    final File file = File('$downloadDirectory/$fileName');

    try {
      // Delete the file if exists.
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      print(error);
    }

    final output = file.openWrite(mode: FileMode.writeOnlyAppend);

    // Track the file download status.
    final len = muxed.size.totalBytes;
    var count = 0;

    // Create the message and set the cursor position.
    final msg = 'Downloading ${video.title}.${muxed.container.name}';
    print(msg);

    // Downloading the file.
    await for (final data in muxedStream) {
      // Keep track of the current downloaded data.
      count += data.length;

      // Calculate the current progress and then display.
      setState(() {
        progress = ((count / len) * 100).ceil();
      });

      // Write to file.
      output.add(data);
    }

    await output.close();

    setState(() {
      isDownloading = false;
      progress = 0;

    });
    // Close the YoutubeExplode's http client.
    yt.close();
  }


  void downloadAudio () async {

    var status = await Permission.storage.request();
    if (status.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please allow storage permission')));
    }

    setState(() {
      isDownloading = true;
    });

    final yt = YoutubeExplode();
    final video = await yt.videos.get(_urlLink);

    final manifest = await yt.videos.streamsClient.getManifest(_urlLink);

    // Muxed
    final audioStreams = manifest.audio;

    // Get the audio track with the highest bitrate.
    final audio = audioStreams.first;

    final audioStream = yt.videos.streamsClient.get(audio);

    // Compose the file name removing the unallowed characters in windows.
    final fileName = '${video.title}.${audio.container.name}'
        .replaceAll(r'\', '')
        .replaceAll('/', '')
        .replaceAll('*', '')
        .replaceAll('?', '')
        .replaceAll('"', '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('|', '');


    final File file = File('$downloadDirectory/$fileName');

    try {
      // Delete the file if exists.
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      print(error);
    }

    final output = file.openWrite(mode: FileMode.writeOnlyAppend);

    // Track the file download status.
    final len = audio.size.totalBytes;
    var count = 0;

    // Create the message and set the cursor position.
    final msg = 'Downloading ${video.title}.${audio.container.name}';
    print(msg);

    // Downloading the file.
    await for (final data in audioStream) {
      // Keep track of the current downloaded data.
      count += data.length;

      // Calculate the current progress and then display.
      setState(() {
        progress = ((count / len) * 100).ceil();
      });

      // Write to file.
      output.add(data);
    }

    await output.close();
    
    setState(() {
      isDownloading = false;
      progress = 0;
    });
    // Close the YoutubeExplode's http client.
    yt.close();

    // TODO Convert 3gpp to mp3.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Youtube Downloader'),
        backgroundColor: Colors.blue[50],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                height: 20,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter Youtube URL',
                ),
                textInputAction: TextInputAction.search,
                controller: _urlLink,
                onFieldSubmitted: (value) {
                  getAvailableResolutions(_urlLink.text);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
                },
              ),
              const SizedBox(
                height: 20,
              ),
              if(_urlLink.text.isNotEmpty) Image.network(getYoutubeThumbnail(_urlLink.text)!),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => getAvailableResolutions(_urlLink.text),
                    icon: const Icon(Icons.list),
                    label: const Text('Video Resolutions')
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => downloadAudio(), 
                    icon: const Icon(Icons.download, size: 24.0,),
                    label: const Text('Audio'),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Text('Download Directory: '),
                            Text(
                              textAlign: TextAlign.start,
                              downloadDirectory,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if(isDownloading) LinearProgressIndicator(value: progress.toDouble() / 100),
              const SizedBox(
                height: 20,
              ),
              
              manifestLoading ? const CircularProgressIndicator() : DownloadList(video: video, downloadVideo: downloadvideo),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadList extends StatelessWidget {
  const DownloadList({
    super.key,
    required this.video,
    required this.downloadVideo
  });

  final List video;
  final Function downloadVideo;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: video.length,
        itemBuilder: (context, index) {

          var details = video[index];
          String resolution = details.videoResolution.toString();
          String type = details.container.name;

          if(details.container.name != 'mp4') return Container();

          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: ListTile(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(index.toString())));
                downloadVideo(index);
              },
              title: Row(
                children: [
                  const Text(style: TextStyle(fontWeight: FontWeight.bold), 'Resolution '),
                  Text('($resolution) '),
                  const Text(style: TextStyle(fontWeight: FontWeight.bold), 'Type '),
                  Text('$type '),
                ],
              ),
              subtitle: Text(details.size.toString()),
              tileColor: const Color.fromARGB(179, 152, 217, 255),
              trailing: const Icon(Icons.download),
            ),
          );
        });
  }
}
