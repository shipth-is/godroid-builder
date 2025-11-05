/**************************************************************************/
/*  GodotFragment.java                                                    */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

package org.godotengine.godot;

import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.utils.BenchmarkUtils;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.CallSuper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * Base fragment for Android apps intending to use Godot for part of the app's UI.
 */
public class GodotFragment extends Fragment implements GodotHost {
	private static final String TAG = GodotFragment.class.getSimpleName();

	private FrameLayout godotContainerLayout;

	@Nullable
	private GodotHost parentHost;
	private Godot godot;

	static private Intent mCurrentIntent;

	public void onNewIntent(Intent intent) {
		mCurrentIntent = intent;
	}

	static public Intent getCurrentIntent() {
		return mCurrentIntent;
	}

	public interface ResultCallback {
		void callback(int requestCode, int resultCode, Intent data);
	}
	public ResultCallback resultCallback;

	@Override
	public Godot getGodot() {
		return godot;
	}

	@Override
	public void onAttach(@NonNull Context context) {
		super.onAttach(context);
		if (getParentFragment() instanceof GodotHost) {
			parentHost = (GodotHost)getParentFragment();
		} else if (getActivity() instanceof GodotHost) {
			parentHost = (GodotHost)getActivity();
		}
	}

	@Override
	public void onDetach() {
		super.onDetach();
		parentHost = null;
	}

	@CallSuper
	@Override
	public void onActivityResult(int requestCode, int resultCode, Intent data) {
		super.onActivityResult(requestCode, resultCode, data);
		if (resultCallback != null) {
			resultCallback.callback(requestCode, resultCode, data);
			resultCallback = null;
		}

		godot.onActivityResult(requestCode, resultCode, data);
	}

	@CallSuper
	@Override
	public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults);
		godot.onRequestPermissionsResult(requestCode, permissions, grantResults);
	}

	@Override
	public void onCreate(Bundle icicle) {
		BenchmarkUtils.beginBenchmarkMeasure("GodotFragment::onCreate");
		super.onCreate(icicle);

		final Activity activity = getActivity();
		mCurrentIntent = activity.getIntent();

		godot = new Godot(requireContext());
		performEngineInitialization();
		BenchmarkUtils.endBenchmarkMeasure("GodotFragment::onCreate");
	}

	private void performEngineInitialization() {
		godot.onCreate(this);

		if (!godot.onInitNativeLayer(this)) {
			Log.e(TAG, "Unable to initialize engine native layer");
			return;
		}

		godotContainerLayout = godot.onInitRenderView(this);
		if (godotContainerLayout == null) {
			Log.e(TAG, "Unable to initialize engine render view");
			return;
		}
	}

	@Override
	public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle icicle) {
		return godotContainerLayout;
	}

	@Override
	public void onDestroy() {
		godot.onDestroy(this);
		super.onDestroy();
	}

	@Override
	public void onPause() {
		super.onPause();
		godot.onPause(this);
	}

	@Override
	public void onResume() {
		super.onResume();
		godot.onResume(this);
	}

	public void onBackPressed() {
		godot.onBackPressed(this);
	}

	@CallSuper
	@Override
	public List<String> getCommandLine() {
		return parentHost != null ? parentHost.getCommandLine() : Collections.emptyList();
	}

	@CallSuper
	@Override
	public void onGodotSetupCompleted() {
		if (parentHost != null) {
			parentHost.onGodotSetupCompleted();
		}
	}

	@CallSuper
	@Override
	public void onGodotMainLoopStarted() {
		if (parentHost != null) {
			parentHost.onGodotMainLoopStarted();
		}
	}

	@Override
	public void onGodotForceQuit(Godot instance) {
		if (parentHost != null) {
			parentHost.onGodotForceQuit(instance);
		}
	}

	@Override
	public boolean onGodotForceQuit(int godotInstanceId) {
		return parentHost != null && parentHost.onGodotForceQuit(godotInstanceId);
	}

	@Override
	public void onGodotRestartRequested(Godot instance) {
		if (parentHost != null) {
			parentHost.onGodotRestartRequested(instance);
		}
	}

	@Override
	public int onNewGodotInstanceRequested(String[] args) {
		if (parentHost != null) {
			return parentHost.onNewGodotInstanceRequested(args);
		}
		return 0;
	}

	@Override
	@CallSuper
	public Set<GodotPlugin> getHostPlugins(Godot engine) {
		if (parentHost != null) {
			return parentHost.getHostPlugins(engine);
		}
		return Collections.emptySet();
	}
}
