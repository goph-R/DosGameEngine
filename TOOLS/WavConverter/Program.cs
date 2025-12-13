using System;
using System.IO;
using System.Text;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: dotnet run <input.wav> <output.wav>");
            return;
        }

        string inputPath = args[0];
        string outputPath = args[1];

        using var input = new BinaryReader(File.OpenRead(inputPath));

        // Read RIFF header
        string riff = new string(input.ReadChars(4));
        int riffSize = input.ReadInt32();
        string wave = new string(input.ReadChars(4));

        if (riff != "RIFF" || wave != "WAVE")
            throw new Exception("Not a valid WAV file.");

        ushort audioFormat = 0;
        ushort channels = 0;
        int sampleRate = 0;
        ushort bitsPerSample = 0;
        byte[] pcmData = null;

        // Read chunks
        while (input.BaseStream.Position < input.BaseStream.Length)
        {
            string chunkId = new string(input.ReadChars(4));
            int chunkSize = input.ReadInt32();

            if (chunkId == "fmt ")
            {
                audioFormat = input.ReadUInt16();
                channels = input.ReadUInt16();
                sampleRate = input.ReadInt32();
                int byteRate = input.ReadInt32();
                ushort blockAlign = input.ReadUInt16();
                bitsPerSample = input.ReadUInt16();

                // Skip remainder
                int extra = chunkSize - 16;
                if (extra > 0)
                    input.ReadBytes(extra);
            }
            else if (chunkId == "data")
            {
                pcmData = input.ReadBytes(chunkSize);
            }
            else
            {
                input.BaseStream.Position += chunkSize;
            }
        }

        if (pcmData == null)
            throw new Exception("WAV has no data chunk.");

        if (audioFormat != 1)
            throw new Exception("Only PCM WAV is supported.");
        if (channels != 1)
            throw new Exception("Only mono WAV is supported.");
        if (bitsPerSample != 16)
            throw new Exception("Expected 16-bit input.");
        if (sampleRate != 44100)
            throw new Exception("Expected 44.1 kHz input WAV.");

        // Convert 44kHz → 11kHz, 16-bit → 8-bit unsigned
        int inputSampleCount = pcmData.Length / 2;
        int step = 4; // 44100 / 11025 = 4
        int outputSampleCount = inputSampleCount / step;

        byte[] outputPcm = new byte[outputSampleCount];

        for (int inIdx = 0, outIdx = 0; outIdx < outputSampleCount; inIdx += step, outIdx++)
        {
            short sample16 = BitConverter.ToInt16(pcmData, inIdx * 2); // signed
            int unsignedSample = sample16 + 32768; // 0..65535
            byte outSample = (byte)(unsignedSample >> 8);
            Console.WriteLine(outSample);
            outputPcm[outIdx] = outSample; // 0..255
        }

        // Write output WAV
        int outSampleRate = 11025;
        ushort outBits = 8;
        ushort outCh = 1;
        byte[] fmtChunk = Encoding.ASCII.GetBytes("fmt ");
        byte[] dataChunk = Encoding.ASCII.GetBytes("data");

        using var output = new BinaryWriter(File.Create(outputPath));

        int dataSize = outputPcm.Length;
        int fmtSize = 16;
        int riffOutSize = 4 + (8 + fmtSize) + (8 + dataSize);

        // RIFF header
        output.Write(Encoding.ASCII.GetBytes("RIFF"));
        output.Write(riffOutSize);
        output.Write(Encoding.ASCII.GetBytes("WAVE"));

        // fmt chunk
        output.Write(fmtChunk);
        output.Write(fmtSize);
        output.Write((ushort)1); // PCM
        output.Write(outCh);
        output.Write(outSampleRate);
        output.Write(outSampleRate * outCh * (outBits / 8)); // byte rate
        output.Write((ushort)(outCh * (outBits / 8))); // block align
        output.Write(outBits);

        // data chunk
        output.Write(dataChunk);
        output.Write(dataSize);
        output.Write(outputPcm);

        Console.WriteLine("Wrote: " + outputPath);
    }
}
